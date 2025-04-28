from chalice import Chalice
from pypdf import PdfReader
import boto3

app = Chalice(app_name='PDFExtractor')

s3 = boto3.client(service_name="s3")

@app.lambda_function()
def pdf_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    try:
        pdf = s3.get_object(Bucket=bucket, Key=key)
        reader = PdfReader(pdf['Body'])
        text = ""
        for page in reader.pages:
            text += page.extract_text()
        output_key = f"txt/{key.rsplit('.', 1)[0]}.txt"
        s3.put_object(Bucket=bucket, Key=output_key, Body=text)
    except Exception as e:
        print(e)
        raise e
    return {}