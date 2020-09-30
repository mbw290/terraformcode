resource "aws_instance" "web" {
  ami           = "ami-0528a5175983e7f28"
  instance_type = "t2.micro"

  tags = {
    Name = "HelloWorld"
  }
}
