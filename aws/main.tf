provider "aws" {
  region = "us-east-1"
}

module "cloudfront_s3_website_without_domain" {
  source             = "chgangaraju/cloudfront-s3-website/aws"
  version            = "1.2.6"
  domain_name        = "playwright-report-s3-example" // This sets the bucket name.
  use_default_domain = true
  upload_sample_file = false
}
# Upload the report to the bucket
resource "aws_s3_object" "index" {
  bucket = module.cloudfront_s3_website_without_domain.s3_bucket_name
  key    = "index.html"
  source = "../playwright-report/index.html"
  etag = filemd5("../playwright-report/index.html")
  content_type = "text/html"
}

resource "aws_s3_object" "trace" {
  for_each = fileset("../playwright-report", "trace/**")
  bucket   = module.cloudfront_s3_website_without_domain.s3_bucket_name
  key      = each.value
  source   = "../playwright-report/${each.value}"
  etag = filemd5("../playwright-report/${each.value}")
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

# data
resource "aws_s3_object" "data" {
  for_each = fileset("../playwright-report", "data/**")
  bucket   = module.cloudfront_s3_website_without_domain.s3_bucket_name
  key      = each.value
  source   = "../playwright-report/${each.value}"
  etag = filemd5("../playwright-report/${each.value}")
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
resource "null_resource" "invalidate_cloudfront_cache" {
  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${module.cloudfront_s3_website_without_domain.cloudfront_dist_id} --paths '/*'"
  }
}
# Output the CloudFront domain name
output "cloudfront_domain_name" {
  value = module.cloudfront_s3_website_without_domain.cloudfront_domain_name
}