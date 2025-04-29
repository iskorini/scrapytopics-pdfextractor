from chalice import Chalice
from pypdf import PdfReader
import boto3
import io
import logging

logger = logging.getLogger()
logger.setLevel("INFO")

app = Chalice(app_name='PDFExtractor')

s3 = boto3.client(service_name="s3")

@app.lambda_function()
def pdf_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    logger.info(event)
    try:
        pdf = s3.get_object(Bucket=bucket, Key=key)
        body = pdf["Body"].read()
        reader = PdfReader(io.BytesIO(body))
        text = ""
        logger.info(f"PDF Pages {str(len(reader.pages))}")
        for page in reader.pages:
            text += page.extract_text()
        logger.info("text extracted")
        output_key = f"txt/{key.rsplit('.', 1)[0]}.txt"
        s3.put_object(Bucket=bucket, Key=output_key, Body=text)
        logger.info(f"text saved in {bucket}/{output_key}")
    except Exception as e:
        print(e)
        raise e
    return {}