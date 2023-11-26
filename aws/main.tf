terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      region  = "us-east-1"
    }
  }
}
provider "aws" {
  region = "us-east-1"
  alias  = "aws_cloudfront"
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    sid = "1"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.domain_name}/*",
    ]

    principals {
      type = "AWS"

      identifiers = [
        aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn,
      ]
    }
  }
}
resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

resource "aws_s3_bucket_website_configuration" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id

  index_document {
    suffix = "index.html"
  }
}
resource "aws_s3_bucket_versioning" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
    aws_s3_bucket.s3_bucket
  ]

  origin {
    domain_name = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id   = "s3-cloudfront"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
    ]

    cached_methods = [
      "GET",
      "HEAD",
    ]

    target_origin_id = "s3-cloudfront"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"

    # https://stackoverflow.com/questions/67845341/cloudfront-s3-etag-possible-for-cloudfront-to-send-updated-s3-object-before-t
    min_ttl     = var.cloudfront_min_ttl
    default_ttl = var.cloudfront_default_ttl
    max_ttl     = var.cloudfront_max_ttl
  }

  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = var.cloudfront_geo_restriction_restriction_type
      locations        = []
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true

  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    error_caching_min_ttl = 0
    response_page_path    = "/index.html"
  }

  wait_for_deployment = false
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "access-identity-${var.domain_name}.s3.amazonaws.com"
}

resource "aws_s3_object" "index" {
  depends_on   = [aws_s3_bucket.s3_bucket]
  bucket       = var.bucket_name
  key          = "index.html"
  source       = "../playwright-report/index.html"
  etag         = filemd5("../playwright-report/index.html")
  content_type = "text/html"
}

resource "aws_s3_object" "trace" {
  depends_on = [aws_s3_bucket.s3_bucket]
  for_each   = fileset("../playwright-report", "trace/**")
  bucket     = var.bucket_name
  key        = each.value
  source     = "../playwright-report/${each.value}"
  etag       = filemd5("../playwright-report/${each.value}")
  # Handle content types: *.webm, *.png, *.zip, *.css, *.js, *.html, *.svg, *.ttf
  content_type = lookup({
    ".webm" = "video/webm"
    ".png"  = "image/png"
    ".zip"  = "application/zip"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".html" = "text/html"
    ".svg"  = "image/svg+xml"
    ".ttf"  = "font/ttf"
  }, substr(each.value, -4, 4), "binary/octet-stream")
}

resource "aws_s3_object" "data" {
  depends_on = [aws_s3_bucket.s3_bucket]
  for_each   = fileset("../playwright-report", "data/**")
  bucket     = var.bucket_name
  key        = each.value
  source     = "../playwright-report/${each.value}"
  etag       = filemd5("../playwright-report/${each.value}")
  content_type = lookup({
    ".webm" = "video/webm"
    ".png"  = "image/png"
    ".zip"  = "application/zip"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".html" = "text/html"
    ".svg"  = "image/svg+xml"
    ".ttf"  = "font/ttf"
  }, substr(each.value, -4, 4), "binary/octet-stream")
}

# Invalidate the CloudFront cache with a local-exec command
# resource "null_resource" "invalidate_cloudfront_cache" {
#   provisioner "local-exec" {
#     command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.s3_distribution.id} --paths '/*'"
#   }
# }
