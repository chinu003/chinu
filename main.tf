provider "aws" {
  region = "ap-northeast-1"
  }


terraform {
  backend "s3" {
    bucket = "vinuuu"
    key = "chinu/terraform.tfstate"
    region = "ap-northeast-1"
  }
}


resource "aws_instance" "ec_1"{
    ami = "ami-0d52744d6551d851e"
    key_name = "vishnu"
    instance_type = "t2.micro"
    tags = {
        Name = "chinu"
    }
}