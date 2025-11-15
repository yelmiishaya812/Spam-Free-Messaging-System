# Spam-Free Messaging System
A decentralized messaging system built on Stacks blockchain that combats spam through economic incentives. Users must stake STX tokens to send messages, creating a natural barrier against spam while ensuring legitimate communication remains affordable and accessible.

## 🌟 Features

- **💰 Stake-to-Send**: Users stake 1 STX to send each message
- **🔥 Spam Burning**: Messages reported as spam (3+ reports) get their stakes burned
- **💸 Refund System**: Legitimate messages can claim refunds after 144 blocks (~24 hours)
- **🚫 User Blocking**: Recipients can block unwanted senders
- **📊 Reputation System**: Track user behavior and reputation scores
- **📈 Statistics**: Comprehensive user and system statistics

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet with STX tokens

### Installation

```bash
git clone <repository-url>
cd spam-free-messaging-system
clarinet check
```

## 📖 Usage

### Sending a Message

```clarity
(contract-call? .spam-free-messaging-system send-message 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 "Hello, this is a legitimate message!")
```

**Parameters:**
- `recipient`: Principal address of the message recipient
- `content`: Message content (max 280 characters)

**Requirements:**
- 1 STX stake (automatically transferred)
- Recipient hasn't blocked you
- Message content is not empty

### Reporting Spam

```clarity
(contract-call? .spam-free-messaging-system report-message u123)
```

**Parameters:**
- `message-id`: ID of the message to report

**Requirements:**
- You cannot report your own messages
- Each user can only report a message once
- Message hasn't been refunded or marked as spam

### Claiming Refunds

```clarity
(contract-call? .spam-free-messaging-system claim-refund u123)
```

**Parameters:**
- `message-id`: ID of your message to refund

**Requirements:**
- You must be the message sender
- 144 blocks (~24 hours) must have passed
- Message has fewer than 3 reports
- Message hasn't been refunded

### Blocking Users

```clarity
(contract-call? .spam-free-messaging-system block-user 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Unblocking Users

```clarity
(contract-call? .spam-free-messaging-system unblock-user 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🔍 Read-Only Functions

### Get Message Details
```clarity
(contract-call? .spam-free-messaging-system get-message u123)
```

### Check User Statistics
```clarity
(contract-call? .spam-free-messaging-system get-user-stats 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Check User Reputation
```clarity
(contract-call? .spam-free-messaging-system get-user-reputation 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Check if User is Blocked
```clarity
(contract-call? .spam-free-messaging-system is-user-blocked 'BLOCKER-ADDRESS 'BLOCKED-ADDRESS)
```

### System Statistics
```clarity
(contract-call? .spam-free-messaging-system get-total-messages)
(contract-call? .spam-free-messaging-system get-total-stakes)
(contract-call? .spam-free-messaging-system get-contract-balance)
```

## ⚙️ Configuration

- **Message Stake**: 1,000,000 µSTX (1 STX)
- **Report Threshold**: 3 reports to mark as spam
- **Refund Window**: 144 blocks (~24 hours)
- **Max Message Length**: 280 characters

## 🛡️ Security Features

- **Economic Spam Prevention**: Staking requirement deters mass spam
- **Community Moderation**: Crowdsourced spam reporting
- **User Control**: Individual blocking capabilities
- **Reputation Tracking**: Long-term behavior monitoring
- **Refund Protection**: Time-locked refunds prevent abuse

## 📊 Error Codes

| Code | Description |
|------|-------------|
| u1   | Cannot send message to yourself |
| u2   | Message content cannot be empty |
| u3   | Message content too long |
| u4   | You are blocked by this user |
| u5   | Message not found |
| u6   | Cannot report your own message |
| u7   | Message already refunded |
| u8   | Message already marked as spam |
| u9   | You have already reported this message |
| u10  | Message not found for refund |
