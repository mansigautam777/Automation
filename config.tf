provider "aws" {
  region= "ap-south-1"
  profile = "mansi"
}

// TO DOWNLOAD THE PEM FILE OF THE KEY-PAIR
resource "tls_private_key" "mansigautamkeyt1" {
  algorithm = "RSA"
  rsa_bits = 4096
}
 resource "local_file" "private_key"{
  content = tls_private_key.mansigautamkeyt1.private_key_pem
  filename= "mansigautamkey1.pem"
  file_permission = 0400
}
//GENERATING A NEW KEY PAIR

resource "aws_key_pair" "mansigautamkey" {
  key_name   = "mansigautamkey1"
  public_key = tls_private_key.mansigautamkeyt1.public_key_openssh
}


//CREATING A NEW SECURITY GROUP WITH SSH AND HTTP

resource "aws_security_group" "mansigautam"{
  name       = "mansigautam_security_group1"
  description ="Allow http inbound traffic"
  vpc_id     = "vpc-1c899474"
  
  ingress {
    description = "http"
    from_port    = 0
    to_port     =80
    protocol    ="tcp"
    cidr_blocks =["0.0.0.0/0"]
  }
  egress {
    from_port    = 0
    to_port     =0
    protocol    ="-1"
    cidr_blocks =["0.0.0.0/0"]
  }
  ingress {
     cidr_blocks = ["0.0.0.0/0"]
     from_port = 22
     to_port = 22
     protocol = "tcp"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
 }
  tags = {
    Name = "mansigautam1"
  }
}

//LAUNCHING A NEW INSTANCE

resource "aws_instance" "task1" {
  ami                = "ami-0447a12f28fddb066"
  instance_type      = "t2.micro"
  key_name           = "mansigautamkey1"
  security_groups    = ["mansigautam_security_group1"]

  tags = {
    Name = "mansigautam1"
  }
}

//CONNECTING TO THE EC2-USER THROUGH SSH

resource "null_resource" "nullremote2"  {

depends_on = [
    aws_instance.task1,
  ]

 connection {
  type = "ssh"
  user = "ec2-user"
  host = aws_instance.task1.public_ip
  private_key = file("C:/Users/user/Desktop/terra/mytest1/mansigautamkey1.pem") 
 }

//ADDING REMOTE PROVISIONER TO INSTALL HTTPD,GIT

 provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

}

//PRINTING THE IP ADDRESS

output "myos_ip" {
  value = aws_instance.task1.public_ip
}

//CREATING A NULL RESOURCE TO SAVE THE IP ADRESS IN A FILE

resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.task1.public_ip} > publicip.txt"
  	}
}



//CREATING A NEW EBS VOLUME

resource "aws_ebs_volume" "mansigautam_volume" {
  availability_zone = aws_instance.task1.availability_zone
  size              = 1

  tags = {
    Name = "mansigautam1"
  }
}

//ATTACHING THE VOLUME TO THE INSTANCE

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.mansigautam_volume.id
  instance_id = aws_instance.task1.id
  force_detach = true
}

//CREATING A NULL RESOURCE TO CONNECT TO THE REMOTE USER 
//AND MOUNT THE EBS VOLUME
//DOWNLOAD THE CODE FROM THE GIT AND SAVE IT IN THE VAR/WWW/HTML FOLDER 

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/user/Desktop/terra/mytest1/mansigautamkey1.pem") 
    host     = aws_instance.task1.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/mansigautam777/website.git /var/www/html/"
    ]
  }
}


// CREATING A S3 BUCKET

resource "aws_s3_bucket" "s3_bucket1" {
  bucket = "mansigautam41"
  acl    = "public-read"

  tags = {
    Name        = "My bucket"
  }
   versioning {
    enabled=true
  }
}

//UPLOADING IMAGE IN THE S3 BUCKET

resource "aws_s3_bucket_object" "image-upload" {
  bucket = aws_s3_bucket.s3_bucket1.bucket
  key    = "Welcome.jpg"
  acl = "public-read"
  content_type = "image/jpg"
  source = "C:\\Users\\user\\Desktop\\terra\\mytest1\\welcome.jpg"
  etag=filemd5("C:\\Users\\user\\Desktop\\terra\\mytest1\\welcome.jpg")
}


//GIVING PUBLIC ACCESS TO THE S3 BUCKET

resource "aws_s3_account_public_access_block" "s3_public_access" {
  block_public_acls   = false
  block_public_policy = false
}

//CREATING A CLOUDFRONT DISTRIBUTION WITH THE S3 BUCKET ALREADY CREATED

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.s3_bucket1.bucket_regional_domain_name}"
    origin_id   = "S3-${aws_s3_bucket.s3_bucket1.bucket}"

     custom_origin_config {
        http_port = 80
        https_port = 80
        origin_protocol_policy = "match-viewer"
        origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
         }
      
  
}
 

  enabled             = true
  is_ipv6_enabled     = true

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.s3_bucket1.bucket}"


    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.s3_bucket1.bucket}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.s3_bucket1.bucket}"


    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      
    }
  }

 
  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

//LAUNCHING THE WEBSITE

resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote3,aws_cloudfront_distribution.s3_distribution
  ]

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.task1.public_ip}/website.html"
  	}
}
