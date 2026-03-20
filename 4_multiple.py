import os

from dotenv import load_dotenv
from groq import Groq
from prompt_toolkit import prompt
from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel

load_dotenv()

console = Console()

key = os.getenv("GROQ_API_KEY")
client = Groq(api_key=key)

MODELS = {
    "1": ("Fast Model", "llama-3.1-8b-instant"),
    "2": ("Big Model", "llama-3.3-70b-versatile"),
    "3": ("Reasoning Model", "qwen/qwen3-32b"),
    "4": ("MoE Model", "meta-llama/llama-4-scout-17b-16e-instruct"),
}

model_keys = list(MODELS.keys())

current_index = 0
responses = {}
user_prompt = ""


def call_llm(model, text):
    # Write this function, we've used it thrice now


def query_all_models(text):

    results = {}

    for FIXME, (FIXME, FIXME) in FIXME.FIXME():

        console.print(f"[cyan]Querying {FIXME}...[/cyan]")

        try:
            output = FIXME(FIXME, FIXME)
        except Exception as e:
            output = f"Error: {e}"

        FIXME[FIXME] = FIXME

    return FIXME


def draw_ui():
    console.clear()
    key = model_keys[current_index]
    model_name, model_id = MODELS[key]

    console.print(
        Panel(
            f"[bold yellow]{user_prompt}[/bold yellow]",
            title="User Prompt",
        )
    )

    md = Markdown(responses.get(key, ""))
    console.print(
        Panel(
            md,
            title=f"{model_name} ({model_id})",
        )
    )
    console.print(
        "\n[green]Controls:[/green]  n = next model | p = previous model | q = new prompt"
    )


while True:

    console.clear()
    console.print(Panel("[bold cyan]LLM Playground[/bold cyan]\n\nEnter your prompt"))

    user_prompt = prompt("> ")

    console.print("\n[bold blue]Sending prompt to all models...[/bold blue]\n")

    responses = query_all_models(user_prompt)

    current_index = 0

    while True:

        draw_ui()

        cmd = prompt("> ")

        if cmd == "n":
            current_index = (current_index + 1) % len(model_keys)

        elif cmd == "p":
            current_index = (current_index - 1) % len(model_keys)

        elif cmd == "q":
            break
