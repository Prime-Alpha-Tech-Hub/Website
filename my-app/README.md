# Prime Alpha Securities — EC2 Deployment

## Prerequisites
- EC2 instance (Amazon Linux 2023, Ubuntu 22/24, or any systemd distro)
- Your `key.pem` file
- IAM role attached to the EC2 instance with DynamoDB access
- Security group with ports 22, 80, 443 open inbound

---

## Deploy in 3 commands

**From your local machine:**

```bash
# 1. Upload the app to EC2
scp -i your-key.pem -r pas-deploy/ ec2-user@<EC2_IP>:~/pas

# 2. SSH in
ssh -i your-key.pem ec2-user@<EC2_IP>

# 3. Deploy (run once inside EC2)
cd ~/pas && sudo bash deploy.sh
```

That's it. The deploy script handles everything:
- Installs Node.js 20 if not present
- Runs `npm install` and `npm run build` (Vite)
- Generates a self-signed TLS cert (or uses yours if you place it in `certs/`)
- Registers a systemd service that auto-starts on reboot
- Starts the app on port 80 (HTTP) + 443 (HTTPS)

---

## Using your own TLS certificate

Place your files here **before** running `deploy.sh`:
```
pas-deploy/
  certs/
    key.pem   ← your private key
    cert.pem  ← your certificate (fullchain if Let's Encrypt)
```

The deploy script will use them automatically and skip generating a self-signed cert.

---

## IAM role credentials

The app uses **no hardcoded AWS keys**. The AWS SDK v3 automatically reads
credentials from the EC2 instance metadata service (IMDS). As long as your EC2
instance has an IAM role with DynamoDB permissions, it just works.

**Minimum IAM policy for the role:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
      "dynamodb:Query"
    ],
    "Resource": "arn:aws:dynamodb:us-east-1:*:table/*"
  }]
}
```

Or attach the managed policy: `AmazonDynamoDBFullAccess`

---

## Useful commands after deployment

```bash
# View live logs
sudo journalctl -u pas -f

# Check status
sudo systemctl status pas

# Restart
sudo systemctl restart pas

# Stop
sudo systemctl stop pas

# Re-deploy after code changes
cd ~/pas && sudo bash deploy.sh
```

---

## Getting a real TLS cert with Let's Encrypt

```bash
# On the EC2 instance (after deploy.sh ran once)
sudo systemctl stop pas
sudo apt-get install -y certbot   # Ubuntu
# or: sudo dnf install -y certbot  (Amazon Linux 2023)

sudo certbot certonly --standalone -d yourdomain.com

# Copy certs
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem  ~/pas/certs/key.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ~/pas/certs/cert.pem

sudo systemctl start pas
```

---

## DynamoDB tables (provisioned by Terraform)

| Table | Primary Key |
|---|---|
| `investor` | `investorId` |
| `portfolios` | `portfolioId` |
| `documents` | `docId` |
| `workers` | `workerId` |
| `calendar` | `eventId` |
| `pe_companies` | `dealId` |
| `credit_application` | `appId` |
| `real_estate` | `assetId` |
| `articles` | `articleId` |
| `enquiries` | `enquiryId` |
