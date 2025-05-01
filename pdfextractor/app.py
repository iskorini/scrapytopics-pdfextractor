from chalice import Chalice
from pypdf import PdfReader
import boto3
import io
import logging
import base64
import hashlib
import os
import json

logger = logging.getLogger()
logger.setLevel("INFO")

app = Chalice(app_name='PDFExtractor')

s3 = boto3.client(service_name="s3")

BUCKET_NAME = os.getenv("BUCKET_NAME")

@app.route("/extract", methods=["POST"], content_types=['application/json'], cors=True)
def pdf_handler(event, context):
    logger.info(event)
    body = event["body"]
    body = json.loads(body)
    try:
        file_b64 = body["file_content"]
        file_bytes = base64.b64decode(file_b64)
        file_hash = hashlib.md5(file_b64).hexdigest()
        key = f"txt/{file_hash}.txt"
        ### check in cache
        try:
            text = s3.get_object(Bucket=BUCKET_NAME, Key=key)
            text = text["Body"].read().decode("utf-8")
            logger.info("returning cached object")
            return {"filename": body["filename"], "text": text, "cached": True}
        except s3.exception.NoSuchKey:
            pass 
        ###
        reader = PdfReader(io.BytesIO(file_bytes))
        text = ""
        logger.info(f"PDF Pages {str(len(reader.pages))}")
        for page in reader.pages:
            text += page.extract_text()
        logger.info("text extracted")
        s3.put_object(Bucket = BUCKET_NAME, Key = key, body=text.encode("utf-8"))
        logger.info(f"text saved in {BUCKET_NAME}/{key}")
        return {"filename": body["filename"], "text": text, "cached": False}
    except Exception as e:
        print(e)
        raise e
    return {}