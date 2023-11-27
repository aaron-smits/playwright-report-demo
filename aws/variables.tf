variable "domain_name" {
  description = "domain name (or application name if no domain name available)"
  default     = "playwright-report-s3-example"
}

variable "bucket_name" {
  description = "bucket name"
  type        = string
  default     = "playwright-report-s3-example"
}

variable "price_class" {
  default     = "PriceClass_100" // Only US,Canada,Europe
  description = "CloudFront distribution price class"
}

variable "cloudfront_min_ttl" {
  default     = 0
  description = "The minimum TTL for the cloudfront cache"
}

variable "cloudfront_default_ttl" {
  default     = 86400
  description = "The default TTL for the cloudfront cache"
}

variable "cloudfront_max_ttl" {
  default     = 31536000
  description = "The maximum TTL for the cloudfront cache"
}

variable "cloudfront_geo_restriction_restriction_type" {
  default     = "none"
  description = "The method that you want to use to restrict distribution of your content by country: none, whitelist, or blacklist."
}
variable "cloudfront_geo_restriction_locations" {
  default     = []
  description = "The ISO 3166-1-alpha-2 codes for which you want CloudFront either to distribute your content (whitelist) or not distribute your content (blacklist)."
}
