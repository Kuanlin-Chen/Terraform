output "instance_id" {
  value = aws_instance.web.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.vpce_bucket.bucket
}