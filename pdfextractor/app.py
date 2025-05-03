from chalice import Chalice
import pymupdf
import boto3
import io
import logging
import base64
import hashlib
import os
import json
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel("INFO")

app = Chalice(app_name='PDFExtractor')

s3 = boto3.client(service_name="s3")

BUCKET_NAME = os.getenv("BUCKET_NAME")

@app.route("/extract", methods=["POST"], content_types=['application/json'])
def pdf_handler(event, context):
    logger.info(event)
    body = event["body"]
    body = json.loads(body)
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type"
    }
    try:
        file_b64 = body["file_content"]
        file_bytes = base64.b64decode(file_b64)
        file_hash = hashlib.md5(file_b64.encode()).hexdigest()
        key = f"txt/{file_hash}.txt"
        ### check in cache
        try:
            text = s3.get_object(Bucket=BUCKET_NAME, Key=key)
            text = text["Body"].read().decode("utf-8")
            logger.info("returning cached object")
            response = {
                "statusCode": 200,
                "headers": headers,
                "body": json.dumps({"filename": body["filename"], "text": text, "cached": True})
            }
            return response
        except ClientError as e:
            if e.response['Error']['Code'] == 'NoSuchKey':
                logger.info("object not found in cache")
            else:
                raise e
        ###
        f = io.BytesIO(file_bytes)
        doc = pymupdf.open(stream=f, filetype="pdf")
        text = ""
        for page in doc:
            text += page.get_text()
        logger.info("text extracted")
        s3.put_object(Bucket=BUCKET_NAME, Key=key, Body=text)
        logger.info(f"text saved in {BUCKET_NAME}/{key}")
        response = {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({"filename": body["filename"], "text": text, "cached": False})
        }
        return response
    except Exception as e:
        print(e)
        raise e
    return {}