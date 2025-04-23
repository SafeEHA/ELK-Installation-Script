# 🛠️ Quick Setup

```bash
git clone https://github.com/SafeEHA/ELK-Installation-Script.git
cd ELK-Installation-Script

## Edit key name and preffered region
nano terraform/main.tf

terraform init
terraform apply

# To run the script on a server

## SSH into your instance
ssh -i your-key.pem ubuntu@<public-ip>

# Run the install script
chmod +x ELK.sh
./ELK.sh
