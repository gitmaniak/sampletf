# KMS Key to Encrypt S3 Bucket
resource "aws_kms_key" "this" {
  description             = var.kms_key_description
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = var.kms_key_enable_key_rotation

  tags = var.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.kms_key_alias}"
  target_key_id = aws_kms_key.this.key_id
}

# Bucket Policy
data "aws_iam_policy_document" "state_force_ssl" {
  statement {
    sid     = "AllowSSLRequestsOnly"
    actions = ["s3:*"]
    effect  = "Deny"
    resources = [
      aws_s3_bucket.backendstate.arn,
      "${aws_s3_bucket.backendstate.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

## Bucket ##

resource "aws_s3_bucket_policy" "state_force_ssl" {
  bucket = aws_s3_bucket.backendstate.id
  policy = data.aws_iam_policy_document.state_force_ssl.json

  depends_on = [aws_s3_bucket_public_access_block.backend]
}

resource "aws_s3_bucket" "backendstate" {
   bucket = "${data.aws_caller_identity.current.account_id}-${var.bucket_name}"
   tags = {
     Name = var.bucket_name
     Environment = "Test"
   }
}

resource "aws_s3_bucket_acl" "state" {
  bucket = aws_s3_bucket.backendstate.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.backendstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.backendstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backend" {
  bucket                  = aws_s3_bucket.backendstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
