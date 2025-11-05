# Read public key from file
locals {
  public_key = file(var.public_key_path)
}

# Create AWS Key Pair
resource "aws_key_pair" "taskops_key" {
  key_name   = var.key_name
  public_key = local.public_key

  tags = {
    Name = "taskops-key"
  }
}

