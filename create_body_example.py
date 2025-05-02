import base64
import json
import pymupdf
import io

def main():
    # Open the PDF file in binary mode
    with open("sample2.pdf", "rb") as pdf_file:
        # Encode the PDF content in base64
        encoded_content = base64.b64encode(pdf_file.read()).decode("utf-8")
    
    # Create a JSON object with the encoded content
    data = {"file_content": encoded_content}
    
    # Save the JSON object to a file
    with open("sample.json", "w") as json_file:
        json.dump(data, json_file, indent=4)


    buffer = base64.b64decode(encoded_content)
    f = io.BytesIO(buffer)
    pdf = pymupdf.open(stream=f, filetype="pdf")
    text = ""
    for page in pdf:
        text += page.get_text()
    print(text.encode("utf-8"))


if __name__ == "__main__":
    main()