Install miniconda

- For windows

```bash
powershell -ExecutionPolicy Bypass -File .\Install-Miniconda.ps1
```

- For linux
```bash
bash install_miniconda.sh 
```

Create environment

```
conda create -n agentic python=3.12
conda activate agentic
pip install -r requirements.txt
```

Create .env file and put Groq api key in there

```env
GROQ_API_KEY=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
```
