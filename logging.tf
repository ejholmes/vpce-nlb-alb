resource "aws_s3_bucket" "access_logs" {
  bucket_prefix = "access-logs"
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::127311923021:root"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.access_logs.id}/*"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.access_logs.id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.access_logs.id}"
        }
    ]
}

POLICY
}

resource "aws_s3_bucket" "flow_logs" {
  bucket_prefix = "flow-logs"
}

resource "aws_s3_bucket_policy" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  policy = <<POLICY
{
      "Version": "2012-10-17",
      "Id": "AWSLogDeliveryWrite20150319",
      "Statement": [
          {
              "Sid": "AWSLogDeliveryWrite",
              "Effect": "Allow",
              "Principal": {
                  "Service": "delivery.logs.amazonaws.com"
              },
              "Action": "s3:PutObject",
              "Resource": "arn:aws:s3:::${aws_s3_bucket.flow_logs.id}/*",
              "Condition": {
                  "StringEquals": {
                      "s3:x-amz-acl": "bucket-owner-full-control"
                  }
              }
          },
          {
              "Sid": "AWSLogDeliveryAclCheck",
              "Effect": "Allow",
              "Principal": {
                  "Service": "delivery.logs.amazonaws.com"
              },
              "Action": "s3:GetBucketAcl",
              "Resource": "arn:aws:s3:::${aws_s3_bucket.flow_logs.id}"
          }
      ]
  }

POLICY
}

resource "aws_glue_catalog_database" "flowlogs" {
  name = "vpc_nlb_alb_flowlogs"
}

resource "aws_glue_catalog_table" "vpc_flowlogs_table" {
  name          = "flowlogs"
  database_name = aws_glue_catalog_database.flowlogs.name
  table_type    = "EXTERNAL_TABLE"
  parameters = {
    EXTERNAL                    = "true"
    "projection.enabled"        = "true"
    "skip.header.line.count"    = "1"
    "projection.region.type"    = "enum"
    "projection.region.values"  = "us-east-1"
    "projection.year.type"      = "date"
    "projection.year.format"    = "yyyy"
    "projection.year.range"     = "2023,NOW"
    "projection.year.interval"  = "1"
    "projection.year.unit"      = "YEARS"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "01,12"
    "projection.month.digits"   = "2"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "01,31"
    "projection.day.digits"     = "2"
    "projection.hour.type"      = "integer"
    "projection.hour.range"     = "00,23"
    "projection.hour.digits"    = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.flow_logs.id}/AWSLogs/aws-account-id=${data.aws_caller_identity.current.account_id}/aws-service=vpcflowlogs/aws-region=$${region}/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/"
  }
  storage_descriptor {
    location = "s3://${aws_s3_bucket.flow_logs.id}/"

    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "version"
      type = "int"
    }
    columns {
      name = "account_id"
      type = "string"
    }
    columns {
      name = "interface_id"
      type = "string"
    }
    columns {
      name = "srcaddr"
      type = "string"
    }
    columns {
      name = "dstaddr"
      type = "string"
    }
    columns {
      name = "srcport"
      type = "int"
    }
    columns {
      name = "dstport"
      type = "int"
    }
    columns {
      name = "protocol"
      type = "bigint"
    }
    columns {
      name = "packets"
      type = "bigint"
    }
    columns {
      name = "bytes"
      type = "bigint"
    }
    columns {
      name = "start"
      type = "bigint"
    }
    columns {
      name = "end"
      type = "bigint"
    }
    columns {
      name = "action"
      type = "string"
    }
    columns {
      name = "log_status"
      type = "string"
    }
    columns {
      name = "vpc_id"
      type = "string"
    }
    columns {
      name = "subnet_id"
      type = "string"
    }
    columns {
      name = "instance_id"
      type = "string"
    }
    columns {
      name = "tcp_flags"
      type = "int"
    }
    columns {
      name = "type"
      type = "string"
    }
    columns {
      name = "pkt_srcaddr"
      type = "string"
    }
    columns {
      name = "pkt_dstaddr"
      type = "string"
    }
    columns {
      name = "az_id"
      type = "string"
    }
    columns {
      name = "sublocation_type"
      type = "string"
    }
    columns {
      name = "sublocation_id"
      type = "string"
    }
    columns {
      name = "pkt_src_aws_service"
      type = "string"
    }
    columns {
      name = "pkt_dst_aws_service"
      type = "string"
    }
    columns {
      name = "flow_direction"
      type = "string"
    }
    columns {
      name = "traffic_path"
      type = "int"
    }
  }

  partition_keys {
    name = "region"
    type = "string"
  }
  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "int"
  }
  partition_keys {
    name = "day"
    type = "int"
  }
  partition_keys {
    name = "hour"
    type = "int"
  }
}
