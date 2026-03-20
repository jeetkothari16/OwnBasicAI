import os

from dotenv import load_dotenv
from groq import Groq

GROQ_API_KEY = "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"

client=Groq(api_key=GROQ_API_KEY)

while True:
    user_input = input("You: ")
    response = client.chat.completions.create(model="llama-3.1-8b-instant",
    messages=[{"role":"user", "content": user_input}])

    print("AI:",response.choices[0].message.content)    