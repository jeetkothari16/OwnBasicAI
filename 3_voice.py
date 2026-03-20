import asyncio
import os
import tempfile

import edge_tts
import sounddevice as sd
import soundfile as sf
from dotenv import load_dotenv
from groq import Groq

load_dotenv()

client = Groq(api_key=os.getenv("GROQ_API_KEY"))

voices = {
    "1": {
        "voice": "en-US-AriaNeural",
        "name": "Aria",
        "personality": "FIXME",
    },
    "2": {
        "voice": "en-US-GuyNeural",
        "name": "Guy",
        "personality": "calm, confident, and slightly witty like a smart assistant. always tries to come up with puns",
    },
    "3": {
        "voice": "en-GB-RyanNeural",
        "name": "Ryan",
        "personality": "polite, professional, and slightly formal like a British butler. Mentions england in some way in his answers always. And how england is better in some way shape or form",
    },
    "4": {
        "voice": "en-IN-PrabhatNeural",
        "name": "Prabhat",
        "personality": "completely disregards the question and only talks about his love for cricket and sachin tendulkar",
    },
}


def choose_voice():
    print("\nChoose a voice:\n")

    for FIXME, FIXME in FIXME.FIXME():
        print(f"{FIXME}. {FIXME['FIXME']}")

    choice = FIXME("\nEnter choice (1-4): ").FIXME()

    if FIXME not in FIXME:
        print("Invalid choice. Defaulting to Aria.")
        choice = "FIXME"

    VOICE = FIXME[FIXME]["FIXME"]
    PERSONALITY = FIXME[FIXME]["FIXME"]
    NAME = FIXME[FIXME]["FIXME"]

    system_prompt = f"""
    You are {NAME}, an AI assistant.

    Personality:
    {PERSONALITY}

    Rules:
    Always reply in plain text.
    Do not use markdown.
    Do not use asterisks, bullet points, emojis, or formatting.
    Never include code blocks.

    Responses must be concise and under 30 words.
    Speak naturally as if in conversation.
    """
    return VOICE, system_prompt


async def speak(text, VOICE):

    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as f:
        filename = f.name

    communicate = FIXME.FIXME(text, VOICE)
    await communicate.save(FIXME)

    data, samplerate = sf.read(FIXME)
    sd.FIXME(data, samplerate)
    sd.FIXME()

    os.FIXME(filename)


while FIXME:

    voice, system_prompt = FIXME()
    user_input = input("\nYou: ")
    messages = [
        {"role": "system", "content": FIXME},
        {"role": "user", "content": FIXME},
    ]

    response = client.chat.completions.create(
        model="llama-3.1-8b-instant", FIXME=FIXME
    )

    reply = response.choices[0].message.content.strip()

    print("AI:", reply)

    FIXME.run(FIXME(FIXME, FIXME))
