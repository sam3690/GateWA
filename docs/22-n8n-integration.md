# 22 - n8n Integration

## Overview

GateWA provides official n8n community nodes for integrating WhatsApp automation into n8n workflows. This enables users to build powerful automations combining WhatsApp messaging with hundreds of other services available in n8n.

**Repository:** https://github.com/sam3690/GateWA-n8n
**npm Package:** `@sam3690/n8n-nodes-gatewa`

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   n8n Workflow  │────▶│  GateWA Node    │────▶│  GateWA API     │
│                 │     │  (credentials)  │     │  (your server)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   n8n Workflow  │◀────│ GateWA Trigger  │◀────│  Webhook POST   │
│   (triggered)   │     │  (listens)      │     │  from GateWA    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Installation

### Via n8n Community Nodes (Recommended)

1. Go to **Settings > Community Nodes**
2. Select **Install**
3. Enter `@sam3690/n8n-nodes-gatewa`
4. Agree to the risks and install
5. Restart n8n

### Manual Installation

```bash
cd ~/.n8n/nodes
npm install @sam3690/n8n-nodes-gatewa
```

## Nodes

### GateWA Node

Execute operations on your GateWA server.

#### Credentials Setup

| Field      | Description                      | Example                  |
| ---------- | -------------------------------- | ------------------------ |
| Server URL | GateWA server URL (without /api) | `https://wa.example.com` |
| API Key    | API key from GateWA dashboard    | `owa_xxxxxxxx...`        |

#### Resources & Operations

| Resource | Operation     | Description                 | Endpoint                                        |
| -------- | ------------- | --------------------------- | ----------------------------------------------- |
| Session  | Get Status    | Get session status          | `GET /api/sessions/:id`                         |
| Session  | List All      | List all sessions           | `GET /api/sessions`                             |
| Message  | Send Text     | Send text message           | `POST /api/sessions/:id/messages/send-text`     |
| Message  | Send Image    | Send image (URL/Base64)     | `POST /api/sessions/:id/messages/send-image`    |
| Message  | Send Document | Send file/document          | `POST /api/sessions/:id/messages/send-document` |
| Message  | Send Location | Send location pin           | `POST /api/sessions/:id/messages/send-location` |
| Contact  | Check Exists  | Check if number on WhatsApp | `GET /api/sessions/:id/contacts/check/:number`  |
| Contact  | Get Info      | Get contact information     | `GET /api/sessions/:id/contacts/:contactId`     |
| Webhook  | Create        | Create a webhook            | `POST /api/sessions/:id/webhooks`               |
| Webhook  | Delete        | Delete a webhook            | `DELETE /api/sessions/:id/webhooks/:webhookId`  |

### GateWA Trigger Node

Start workflows when WhatsApp events occur.

#### Supported Events

| Event                  | Description               | Use Case                 |
| ---------------------- | ------------------------- | ------------------------ |
| `message.received`     | New incoming message      | Auto-reply, lead capture |
| `message.sent`         | Message sent successfully | Delivery confirmation    |
| `session.connected`    | Session authenticated     | Startup notifications    |
| `session.disconnected` | Session lost connection   | Alert monitoring         |
| `session.qr_ready`     | QR code generated         | Reconnection alerts      |

#### How It Works

1. When workflow is activated, the trigger creates a webhook in GateWA
2. GateWA sends events to n8n's webhook URL
3. When workflow is deactivated, the webhook is automatically deleted

#### Output Data Format

```json
{
  "event": "message.received",
  "timestamp": "2024-01-15T10:30:00Z",
  "sessionId": "default",
  "data": {
    "messageId": "3EB0F5A2B4C...",
    "chatId": "628123456789@c.us",
    "from": "628123456789@c.us",
    "body": "Hello!",
    "type": "text",
    "timestamp": 1705312200
  }
}
```

## Example Workflows

### 1. Auto-Reply Bot

Automatically reply to incoming messages with a welcome message.

```
[GateWA Trigger] → [IF: Check keyword] → [GateWA: Send Text]
     │
     └── Events: message.received
```

**Configuration:**

- Trigger: `message.received`
- IF Node: Check if `{{$json.data.body}}` contains "hello"
- GateWA: Send Text with welcome message

### 2. Lead Collection to Google Sheets

Capture incoming messages and save to Google Sheets.

```
[GateWA Trigger] → [Google Sheets: Append] → [GateWA: Send Text]
     │                    │
     │                    └── Save: name, phone, message
     └── Events: message.received
```

### 3. Session Monitoring

Get notified on Slack when WhatsApp session disconnects.

```
[GateWA Trigger] → [Slack: Send Message]
     │
     └── Events: session.disconnected
```

**Slack Message:**

```
⚠️ WhatsApp session "{{$json.sessionId}}" disconnected!
Time: {{$json.timestamp}}
Please check and reconnect.
```

### 4. Order Notification

Send WhatsApp notification when new order is received.

```
[Webhook: New Order] → [GateWA: Send Text]
                            │
                            └── "Thank you for your order #{{$json.orderId}}"
```

### 5. Scheduled Reminders

Send daily reminders to a list of contacts.

```
[Schedule Trigger] → [Google Sheets: Get Rows] → [Loop] → [GateWA: Send Text]
     │                      │                                    │
     └── Daily 9AM          └── Get contacts                     └── Send reminder
```

## Best Practices

### 1. Error Handling

Always add error handling in your workflows:

```
[GateWA Node] → [IF: Check success] → [Continue...]
                      │
                      └── [Error Handler]
```

### 2. Rate Limiting

WhatsApp has rate limits. Add delays between messages:

```
[Loop Over Items] → [Wait: 2 seconds] → [GateWA: Send Text]
```

### 3. Message Formatting

Use WhatsApp formatting in your messages:

- Bold: `*text*`
- Italic: `_text_`
- Strikethrough: `~text~`
- Monospace: `` `text` ``

### 4. Phone Number Format

Always use the correct format for chat IDs:

- Personal: `628123456789@c.us`
- Group: `123456789-123456789@g.us`

## Troubleshooting

### Credential Test Failed

1. Verify GateWA server is running
2. Check API key is correct
3. Ensure server URL doesn't have trailing slash
4. Verify network connectivity between n8n and GateWA

### Trigger Not Receiving Events

1. Check webhook was created in GateWA dashboard
2. Verify n8n webhook URL is accessible from GateWA server
3. Check firewall/proxy settings
4. Ensure session is connected and active

### Message Not Sending

1. Verify session status is "READY"
2. Check chat ID format is correct
3. Ensure recipient number exists on WhatsApp
4. Check message content isn't empty

## Development

### Building from Source

```bash
git clone https://github.com/sam3690/GateWA-n8n.git
cd GateWA-n8n
npm install
npm run build
```

### Local Development

```bash
# Watch mode
npm run dev

# Link to local n8n
cd ~/.n8n/nodes
npm link /path/to/GateWA-n8n
```

### Testing

Test your changes with a local n8n instance:

```bash
# Start n8n
n8n start

# Or with Docker
docker run -it --rm \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n
```

## Related Documentation

- [GateWA API Specification](./06-api-specification.md)
- [Webhook System](./03-system-architecture.md#webhooks)
- [n8n Documentation](https://docs.n8n.io/)

---

<div align="center">

[← 21 - Glossary](./21-glossary.md) · [Documentation Index](./README.md)

</div>
