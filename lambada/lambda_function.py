import json

def lambda_handler(event, context):
    print("Received event: ", json.dumps(event, indent=2))
    
    # Get the bucket name and file name from the event
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    file_name = event['Records'][0]['s3']['object']['key']
    
    print(f"File uploaded to {bucket_name}/{file_name}")
    
    return {
        'statusCode': 200,
        'body': json.dumps(f"File uploaded to {bucket_name}/{file_name}")
    }