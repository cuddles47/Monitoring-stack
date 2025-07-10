package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"
)

// Discord color values
const (
	ColorRed       = 0xd00000
	ColorGreen     = 0x36A64F
	ColorGrey      = 0x95A5A6
	AlertNameLabel = "alertname"
)

type AlertManagerData struct {
	Receiver string             `json:"receiver"`
	Status   string             `json:"status"`
	Alerts   AlertManagerAlerts `json:"alerts"`

	GroupLabels       KV `json:"groupLabels"`
	CommonLabels      KV `json:"commonLabels"`
	CommonAnnotations KV `json:"commonAnnotations"`

	ExternalURL string `json:"externalURL"`
	GroupKey    string `json:"groupKey"`
	Version     string `json:"version"`
}

type AlertManagerAlert struct {
	Status       string    `json:"status"`
	Labels       KV        `json:"labels"`
	Annotations  KV        `json:"annotations"`
	StartsAt     time.Time `json:"startsAt"`
	EndsAt       time.Time `json:"endsAt"`
	GeneratorURL string    `json:"generatorURL"`
	Fingerprint  string    `json:"fingerprint"`
}

// KV is a set of key/value string pairs.
type KV map[string]string

// Pair is a key/value string pair.
type Pair struct {
	Name, Value string
}

// Pairs is a list of key/value string pairs.
type Pairs []Pair

// SortedPairs returns a sorted list of key/value pairs.
func (kv KV) SortedPairs() Pairs {
	var (
		pairs     = make([]Pair, 0, len(kv))
		keys      = make([]string, 0, len(kv))
		sortStart = 0
	)
	for k := range kv {
		if k == AlertNameLabel {
			keys = append([]string{k}, keys...)
			sortStart = 1
		} else {
			keys = append(keys, k)
		}
	}
	sort.Strings(keys[sortStart:])

	for _, k := range keys {
		pairs = append(pairs, Pair{k, kv[k]})
	}
	return pairs
}

// Alerts is a list of Alert objects.
type AlertManagerAlerts []AlertManagerAlert

type DiscordEmbedFooter struct {
	Text string `json:"text"`
}

type DiscordMessage struct {
	Content   string        `json:"content"`
	Username  string        `json:"username"`
	AvatarURL string        `json:"avatar_url"`
	Embeds    DiscordEmbeds `json:"embeds"`
}

type DiscordEmbeds []DiscordEmbed

type DiscordEmbed struct {
	Title       string              `json:"title"`
	Description string              `json:"description"`
	URL         string              `json:"url"`
	Color       int                 `json:"color"`
	Fields      DiscordEmbedFields  `json:"fields"`
	Footer      *DiscordEmbedFooter `json:"footer,omitempty"`
	Timestamp   *time.Time          `json:"timestamp,omitempty"`
}

type DiscordEmbedFields []DiscordEmbedField

type DiscordEmbedField struct {
	Name   string `json:"name"`
	Value  string `json:"value"`
	Inline bool   `json:"inline"`
}

const defaultListenAddress = "127.0.0.1:9099"
const discordEmbedLimit = 2  // Giảm xuống 2 để tránh quá tải message
const maxDescriptionLength = 200  // Giảm xuống 200 để tránh vượt quá Discord limit
const maxFieldValueLength = 150   // Giảm xuống 150 để tránh vượt quá Discord limit
const maxTitleLength = 150       // Giới hạn độ dài title
const maxAlertsPerMessage = 1    // Chỉ 1 alert per message để tránh quá tải

var (
	webhookURL               = flag.String("webhook.url", os.Getenv("DISCORD_WEBHOOK"), "Discord WebHook URL.")
	additionalWebhookURLFlag = flag.String("additionalWebhook.urls", os.Getenv("ADDITIONAL_DISCORD_WEBHOOKS"), "Additional Discord WebHook URLs.")
	listenAddress            = flag.String("listen.address", os.Getenv("LISTEN_ADDRESS"), "Address:Port to listen on.")
	username                 = flag.String("username", os.Getenv("DISCORD_USERNAME"), "Overrides the predefined username of the webhook.")
	avatarURL                = flag.String("avatar.url", os.Getenv("DISCORD_AVATAR_URL"), "Overrides the predefined avatar of the webhook.")
	verboseMode              = flag.String("verbose", os.Getenv("VERBOSE"), "Verbose mode")
	additionalWebhookURLs    []string
)

func checkWebhookURL(webhookURL string) bool {
	if webhookURL == "" {
		log.Fatalf("Environment variable 'DISCORD_WEBHOOK' or CLI parameter 'webhook.url' not found.")
		return false
	}
	_, err := url.Parse(webhookURL)
	if err != nil {
		log.Fatalf("The Discord WebHook URL doesn't seem to be a valid URL.")
		return false
	}

	re := regexp.MustCompile(`https://discord(?:app)?.com/api/webhooks/[0-9]{18,19}/[a-zA-Z0-9_-]+`)
	if ok := re.Match([]byte(webhookURL)); !ok {
		log.Printf("The Discord WebHook URL doesn't seem to be valid.")
		return false
	}
	return true
}
func checkDiscordUserName(discordUserName string) {
	if discordUserName == "" {
		log.Fatalf("Environment variable 'DISCORD_USERNAME' or CLI parameter 'username' not found.")
	}
	_, err := url.Parse(discordUserName)
	if err != nil {
		log.Fatalf("The Discord UserName doesn't seem to be a valid.")
	}
}

// Truncate string if too long
func truncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}

func sendWebhook(alertManagerData *AlertManagerData) {

	groupedAlerts := make(map[string]AlertManagerAlerts)

	for _, alert := range alertManagerData.Alerts {
		groupedAlerts[alert.Status] = append(groupedAlerts[alert.Status], alert)
	}

	for status, alerts := range groupedAlerts {

		color := findColor(status)

		// Process each alert individually to avoid overloading messages
		for indx, alert := range alerts {
			embeds := DiscordEmbeds{}
			
			// Create title safely with Discord limits (256 chars)
			alertTitle := getAlertTitle(&alert)
			alertTitle = strings.TrimSpace(strings.ReplaceAll(alertTitle, "(instance )", ""))
			alertTitle = strings.TrimSpace(strings.ReplaceAll(alertTitle, "(instance)", ""))
			alertTitle = truncateString(alertTitle, 250)  // Discord limit 256, để margin
			if alertTitle == "" || strings.TrimSpace(alertTitle) == "" {
				alertTitle = "Alert Notification"
			}
			
			embedAlertMessage := DiscordEmbed{
				Title:  alertTitle,
				Color:  color,
				Fields: DiscordEmbedFields{},
			}

			// Add description safely within Discord limits
			desc := ""
			if alert.Annotations["summary"] != "" {
				desc = strings.TrimSpace(alert.Annotations["summary"])
			} else if alert.Annotations["description"] != "" {
				desc = strings.TrimSpace(alert.Annotations["description"])
			}
			
			// Clean up description
			if desc != "" {
				desc = strings.TrimSpace(strings.ReplaceAll(desc, "map[]", ""))
				desc = strings.TrimSpace(strings.ReplaceAll(desc, "(instance )", ""))
				desc = strings.TrimSpace(strings.ReplaceAll(desc, "(instance)", ""))
				if strings.TrimSpace(desc) != "" {
					desc = truncateString(desc, 1000)  // Giới hạn description
					embedAlertMessage.Description = desc
				}
			}

			// Add message field if meaningful and different from summary
			if msg := strings.TrimSpace(alert.Annotations["message"]); msg != "" && 
               msg != alert.Annotations["summary"] {
                msg = strings.TrimSpace(strings.ReplaceAll(msg, "map[]", ""))
                msg = strings.TrimSpace(strings.ReplaceAll(msg, "(instance )", ""))
                if msg != "" {
                    msg = truncateString(msg, 800)  // Discord field limit 1024
                    embedAlertMessage.Fields = append(embedAlertMessage.Fields, DiscordEmbedField{
                        Name:   "Message",
                        Value:  msg,
                        Inline: false,
                    })
                }
            }

            // Add description field if meaningful and different
            if desc := strings.TrimSpace(alert.Annotations["description"]); desc != "" && 
               desc != embedAlertMessage.Description {
                desc = strings.TrimSpace(strings.ReplaceAll(desc, "map[]", ""))
                desc = strings.TrimSpace(strings.ReplaceAll(desc, "(instance )", ""))
                if desc != "" && len(desc) > 10 {
                    desc = truncateString(desc, 800)  // Discord field limit 1024
                    embedAlertMessage.Fields = append(embedAlertMessage.Fields, DiscordEmbedField{
                        Name:   "Description",
                        Value:  desc,
                        Inline: false,
                    })
                }
            }

            // Add details field with labels (cleaned up)
            if details := getFormattedLabels(alert.Labels); details != "" {
                embedAlertMessage.Fields = append(embedAlertMessage.Fields, DiscordEmbedField{
                    Name:   "Details",
                    Value:  details,
                    Inline: false,
                })
            }

            // Add footer and timestamp
            if *username != "" {
                footer := DiscordEmbedFooter{Text: *username}
                embedAlertMessage.Footer = &footer
                currentTime := time.Now()
                embedAlertMessage.Timestamp = &currentTime
            }

            // Only add embed if it has meaningful content
            if len(strings.TrimSpace(embedAlertMessage.Title)) > 3 &&
               (len(strings.TrimSpace(embedAlertMessage.Description)) > 3 || len(embedAlertMessage.Fields) > 0) {
                embeds = append(embeds, embedAlertMessage)
            }

            // Send each alert individually to avoid overloading
            if len(embeds) > 0 {
                log.Printf("Sending individual alert to Discord (alert %d/%d)", indx+1, len(alerts))
                postMessageToDiscord(alertManagerData, status, color, embeds)
				
				// Delay between messages to avoid rate limiting
				time.Sleep(200 * time.Millisecond)
			}
		}
	}
}

func postMessageToDiscord(alertManagerData *AlertManagerData, status string, color int, embeds DiscordEmbeds) {
	discordMessage := DiscordMessage{}
	addOverrideFields(&discordMessage)
	
	// Chỉ gửi embeds của individual alerts, không gửi header
	discordMessage.Embeds = embeds
	
	// Validate message before sending
	if !validateDiscordMessage(&discordMessage) {
		log.Printf("Invalid Discord message structure, skipping send")
		return
	}
	
	discordMessageBytes, err := json.Marshal(discordMessage)
	if err != nil {
		log.Printf("Failed to marshal Discord message: %v", err)
		return
	}
	
	if *verboseMode == "ON" || *verboseMode == "true" {
		log.Printf("Sending webhook message to Discord: %s", string(discordMessageBytes))
	}
	
	sendToWebhook(*webhookURL, discordMessageBytes)
	for _, webhook := range additionalWebhookURLs {
		sendToWebhook(webhook, discordMessageBytes)
	}
}

// Validate Discord message structure
func validateDiscordMessage(message *DiscordMessage) bool {
	// Check if message has content
	if message.Content == "" && len(message.Embeds) == 0 {
		log.Printf("Message has no content or embeds")
		return false
	}
	
	// Check total number of embeds (Discord limit is 10)
	if len(message.Embeds) > 10 {
		log.Printf("Message has too many embeds: %d (max: 10)", len(message.Embeds))
		return false
	}
	
	// Estimate total message size
	totalSize := 0
	
	// Validate embeds
	for i, embed := range message.Embeds {
		embedSize := 0
		
		// Kiểm tra embed có content không
		hasContent := embed.Title != "" || embed.Description != "" || len(embed.Fields) > 0
		if !hasContent {
			log.Printf("Embed %d has no content", i)
			return false
		}
		
		// Check Discord limits - Title
		if len(embed.Title) > 256 {
			log.Printf("Embed %d title too long: %d chars", i, len(embed.Title))
			return false
		}
		embedSize += len(embed.Title)
		
		// Check Discord limits - Description  
		if len(embed.Description) > 4096 {
			log.Printf("Embed %d description too long: %d chars", i, len(embed.Description))
			return false
		}
		embedSize += len(embed.Description)
		
		// Validate URL if present
		if embed.URL != "" {
			if _, err := url.Parse(embed.URL); err != nil {
				log.Printf("Embed %d has invalid URL: %s", i, embed.URL)
				// Don't return false, just log warning
			}
		}
		
		// Check fields count
		if len(embed.Fields) > 25 {
			log.Printf("Embed %d has too many fields: %d", i, len(embed.Fields))
			return false
		}
		
		// Validate fields
		for j, field := range embed.Fields {
			fieldName := strings.TrimSpace(field.Name)
			fieldValue := strings.TrimSpace(field.Value)
			
			if fieldName == "" {
				log.Printf("Embed %d field %d has empty name", i, j)
				return false
			}
			if fieldValue == "" {
				log.Printf("Embed %d field %d has empty value", i, j)
				return false
			}
			if len(fieldName) > 256 {
				log.Printf("Embed %d field %d name too long: %d chars", i, j, len(fieldName))
				return false
			}
			embedSize += len(fieldName)
			
			if len(fieldValue) > 1024 {
				log.Printf("Embed %d field %d value too long: %d chars", i, j, len(fieldValue))
				return false
			}
			embedSize += len(fieldValue)
		}
		
		totalSize += embedSize
	}
	
	// Check total message size (Discord limit is 6000 characters total)
	if totalSize > 5000 {
		log.Printf("Message too large: %d chars (max: 5000)", totalSize)
		return false
	}
	
	return true
}

func sendToWebhook(webHook string, discordMessageBytes []byte) {
	// Add small delay to avoid rate limiting
	time.Sleep(100 * time.Millisecond)
	
	response, err := http.Post(webHook, "application/json", bytes.NewReader(discordMessageBytes))
	if err != nil {
		log.Printf("HTTP Error: %v", err)
		return
	}
	defer response.Body.Close()
	
	// Read response body for better error handling
	responseData, err := ioutil.ReadAll(response.Body)
	if err != nil {
		log.Printf("Failed to read response body: %v", err)
		return
	}
	
	// Success is indicated with 2xx status codes:
	statusOK := response.StatusCode >= 200 && response.StatusCode < 300
	if !statusOK {
		log.Printf("Discord API Error (Status %d): %s", response.StatusCode, string(responseData))
		
		// Handle specific Discord errors
		if response.StatusCode == 400 {
			log.Printf("Bad Request - Check embed structure and content length")
		} else if response.StatusCode == 429 {
			log.Printf("Rate Limited - Consider reducing message frequency")
		}
	} else {
		log.Printf("Successfully sent to Discord (Status: %d)", response.StatusCode)
		if *verboseMode == "ON" || *verboseMode == "true" {
			log.Printf("Discord Response: %s", string(responseData))
		}
	}
}

func buildDiscordMessage(alertManagerData *AlertManagerData, status string, numberOfAlerts int, color int) DiscordMessage {
	discordMessage := DiscordMessage{}
	addOverrideFields(&discordMessage)
	
	// Tạo header message an toàn
	alertName := getAlertName(alertManagerData)
	alertName = truncateString(alertName, maxTitleLength)
	
	// Đảm bảo title không rỗng
	title := fmt.Sprintf("[%s] %s", strings.ToUpper(status), alertName)
	if title == "" || len(strings.TrimSpace(title)) == 0 {
		title = fmt.Sprintf("[%s] Alert", strings.ToUpper(status))
	}
	title = truncateString(title, maxTitleLength)
	
	// Tạo description an toàn
	description := ""
	if alertManagerData.CommonAnnotations["summary"] != "" {
		description = truncateString(alertManagerData.CommonAnnotations["summary"], maxDescriptionLength)
	} else if len(alertManagerData.Alerts) > 0 && alertManagerData.Alerts[0].Annotations["summary"] != "" {
		description = truncateString(alertManagerData.Alerts[0].Annotations["summary"], maxDescriptionLength)
	}
	
	// Validate URL
	externalURL := ""
	if alertManagerData.ExternalURL != "" {
		if _, err := url.Parse(alertManagerData.ExternalURL); err == nil {
			externalURL = alertManagerData.ExternalURL
		} else {
			log.Printf("Invalid external URL: %s, skipping", alertManagerData.ExternalURL)
		}
	}
	
	messageHeader := DiscordEmbed{
		Title:       title,
		Description: description,
		Color:       color,
		Fields:      DiscordEmbedFields{},
	}
	
	// Chỉ set URL nếu hợp lệ
	if externalURL != "" {
		messageHeader.URL = externalURL
	}
	
	// Add timestamp to header
	if *username != "" {
		footer := DiscordEmbedFooter{Text: *username}
		messageHeader.Footer = &footer
		currentTime := time.Now()
		messageHeader.Timestamp = &currentTime
	}
	
	discordMessage.Embeds = DiscordEmbeds{messageHeader}
	return discordMessage
}

func addOverrideFields(discordMessage *DiscordMessage) {
	if *username != "" {
		discordMessage.Username = *username
	}
	if *avatarURL != "" {
		discordMessage.AvatarURL = *avatarURL
	}
}

func getFormattedLabels(labels KV) string {
    var builder strings.Builder
    count := 0
    maxLabels := 3
    
    for _, pair := range labels.SortedPairs() {
        if count >= maxLabels {
            builder.WriteString("• ...and more")
            break
        }
        
        // Skip known invalid or empty values
        value := strings.TrimSpace(pair.Value)
        if value == "" || value == "map[]" || value == "(instance)" || value == "(instance )" || value == "undefined" || value == "null" {
            continue
        }
        
        // Skip instance label if empty
        if pair.Name == "instance" && (value == "" || value == " ") {
            continue
        }
        
        // Truncate value if too long
        if len(value) > 25 {
            value = value[:22] + "..."
        }
        
        builder.WriteString(fmt.Sprintf("• %s: %s\n", pair.Name, value))
        count++
    }
    
    result := strings.TrimSpace(builder.String())
    if result == "" || result == "• ...and more" {
        return ""
    }
    return result
}

func getAlertTitle(alertManagerAlert *AlertManagerAlert) string {
	var builder strings.Builder
	
	// Ưu tiên summary trước
	if alertManagerAlert.Annotations["summary"] != "" {
		summary := strings.TrimSpace(alertManagerAlert.Annotations["summary"])
		if summary != "" {
			builder.WriteString(summary)
		}
	} else if alertManagerAlert.Labels["alertname"] != "" {
		alertname := strings.TrimSpace(alertManagerAlert.Labels["alertname"])
		if alertname != "" {
			builder.WriteString(alertname)
		}
	} else {
		builder.WriteString("Alert Notification")
	}
	
	// Add severity if available
	if alertManagerAlert.Labels["severity"] != "" {
		severity := strings.TrimSpace(alertManagerAlert.Labels["severity"])
		if severity != "" {
			builder.WriteString(fmt.Sprintf(" [%s]", severity))
		}
	}
	
	result := strings.TrimSpace(builder.String())
	if result == "" {
		return "Alert Notification"
	}
	return result
}

func findColor(status string) int {
	color := ColorGrey
	if status == "firing" {
		color = ColorRed
	} else if status == "resolved" {
		color = ColorGreen
	}
	return color
}

func isNotBlankOrEmpty(str string) bool {
	re := regexp.MustCompile(`\S+`)
	return re.MatchString(str)
}

func getAlertName(alertManagerData *AlertManagerData) string {
	icon := ""
	if alertManagerData.Status == "firing" {
		if alertManagerData.CommonLabels["severity"] == "critical" {
			icon = "🔥 "
		} else if alertManagerData.CommonLabels["severity"] == "warning" {
			icon = "⚠️ "
		} else {
			icon = "ℹ️ "
		}
	} else {
		icon = "💚 "
	}

	// Ưu tiên lấy tên từ CommonAnnotations trước
	if alertManagerData.CommonAnnotations["summary"] != "" {
		return icon + alertManagerData.CommonAnnotations["summary"]
	}
	if alertManagerData.CommonAnnotations["message"] != "" {
		return icon + alertManagerData.CommonAnnotations["message"]
	}
	if alertManagerData.CommonAnnotations["description"] != "" {
		desc := alertManagerData.CommonAnnotations["description"]
		// Truncate nếu quá dài và chỉ lấy dòng đầu tiên
		if len(desc) > 50 {
			desc = strings.Split(desc, "\n")[0]
			if len(desc) > 50 {
				desc = desc[:47] + "..."
			}
		}
		return icon + desc
	}
	
	// Fallback về CommonLabels
	if alertManagerData.CommonLabels["alertname"] != "" {
		return icon + alertManagerData.CommonLabels["alertname"]
	}
	
	// Last resort - lấy từ alert đầu tiên
	if len(alertManagerData.Alerts) > 0 {
		firstAlert := alertManagerData.Alerts[0]
		if firstAlert.Annotations["summary"] != "" {
			return icon + firstAlert.Annotations["summary"]
		}
		if firstAlert.Labels["alertname"] != "" {
			return icon + firstAlert.Labels["alertname"]
		}
	}
	
	return icon + "Multiple Alerts"
}

func sendRawPromAlertWarn() {
	badString := `This program is suppose to be fed by alert manager.` + "\n" +
		`It is not a replacement for alert manager, it is a ` + "\n" +
		`webhook target for it. Please read the README.md  ` + "\n" +
		`for guidance on how to configure it for alertmanager` + "\n" +
		`or https://prometheus.io/docs/alerting/latest/configuration/#webhook_config`

	log.Print(`/!\ -- You have misconfigured this program -- /!\`)
	log.Print(`--- --                                      -- ---`)
	log.Print(badString)

	discordMessage := DiscordMessage{
		Content: "",
		Embeds: DiscordEmbeds{
			{
				Title:       "misconfigured program",
				Description: badString,
				Color:       ColorGrey,
				Fields:      DiscordEmbedFields{},
			},
		},
	}

	discordMessageBytes, _ := json.Marshal(discordMessage)
	http.Post(*webhookURL, "application/json", bytes.NewReader(discordMessageBytes))
}

func main() {
	flag.Parse()
	checkWebhookURL(*webhookURL)
	for _, additionalWebhook := range strings.Split(*additionalWebhookURLFlag, ",") {
		if isNotBlankOrEmpty(additionalWebhook) && checkWebhookURL(additionalWebhook) {
			additionalWebhookURLs = append(additionalWebhookURLs, additionalWebhook)
		}
	}
	checkDiscordUserName(*username)

	if *listenAddress == "" {
		*listenAddress = defaultListenAddress
	}

	log.Printf("Listening on: %s", *listenAddress)
	log.Fatal(http.ListenAndServe(*listenAddress, http.HandlerFunc(handleWebHook)))
}

func handleWebHook(w http.ResponseWriter, r *http.Request) {
	log.Printf("%s - [%s] %s", r.Host, r.Method, r.URL.RawPath)

	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		panic(err)
	}

	if *verboseMode == "ON" {
		log.Printf("request payload: %s", string(body))
	}

	alertManagerData := AlertManagerData{}
	err = json.Unmarshal(body, &alertManagerData)
	if err != nil {
		if isRawPromAlert(body) {
			sendRawPromAlertWarn()
			return
		}
		if len(body) > 1024 {
			log.Printf("Failed to unpack inbound alert request - %s...", string(body[:1023]))

		} else {
			log.Printf("Failed to unpack inbound alert request - %s", string(body))
		}
		return
	}
	sendWebhook(&alertManagerData)
}

// isValidField kiểm tra field có hợp lệ không
func isValidField(name string, value string) bool {
    name = strings.TrimSpace(name)
    value = strings.TrimSpace(value)
    
    if name == "" || value == "" {
        return false
    }
    
    // Check for meaningless content
    invalidContents := []string{
        "-", "...", "No details available", "map[]", "(instance )", "(instance)", "undefined", "null"}
    
    for _, invalid := range invalidContents {
        if name == invalid || value == invalid {
            return false
        }
    }
    
    // Remove common placeholder patterns
    value = strings.TrimSpace(strings.ReplaceAll(value, "map[]", ""))
    value = strings.TrimSpace(strings.ReplaceAll(value, "(instance )", ""))
    value = strings.TrimSpace(strings.ReplaceAll(value, "(instance)", ""))
    
    // After cleaning, check if there's actual content
    return len(name) > 0 && len(value) > 0 && !strings.Contains(value, "undefined") && !strings.Contains(value, "null")
}
