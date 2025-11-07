# pdfreadR

> **Automated Literature Review Tool for Water Research Papers**

A robust R-based system for processing and summarizing academic papers using Retrieval-Augmented Generation (RAG) with local LLMs via Ollama.

## 📋 Overview

This project automates the extraction and summarization of academic papers focusing on:

- Advanced Metering Infrastructure (AMI)
- Outdoor watering event detection
- Water event disaggregation
- Residential water consumption patterns

The tool processes PDFs using RAG techniques to generate structured summaries including paper type, research gaps, methods, and results in a standardized format.

## 🚀 Features

- **Batch PDF Processing**: Process multiple academic papers sequentially with progress tracking
- **RAG-Powered Summarization**: Uses local embeddings and LLMs for accurate, context-aware summaries
- **Error Handling & Recovery**: Robust retry logic handles Ollama crashes and network errors
- **Memory-Safe**: Implements chunking strategies and batch processing to prevent memory overflow
- **Structured Output**: Generates consistent summaries with paper type, goals, methods, and results tables

## 📦 Prerequisites

### System Requirements

- R >= 4.5.0
- [Ollama](https://ollama.ai/) installed and running
- At least 8GB RAM (16GB recommended)

### R Packages

```r
install.packages(c(
  "ragnar",
  "ellmer",
  "fs",
  "tidyverse",
  "glue",
  "blastula",
  "progressr",
  "here"
))
```

### Ollama Models

Pull the required models:

```bash
ollama pull nomic-embed-text:latest
ollama pull llama3.2
```

## 📁 Project Structure

```
pdfreadR/
├── AMI_Papers/          # Zotero library folder (optional)
├── AMI_pdfs/            # PDF files to process (required)
├── pdfrag.R             # Main processing script
├── process_single_paper.R  # Core paper processing function
├── file_cleanup.R       # Utility scripts
└── README.md            # This file
```

## 🔧 Setup

1. **Start Ollama**:

   ```bash
   ollama serve
   ```

2. **Place PDFs**: Add your academic papers to the `AMI_pdfs/` directory

3. **Configure System Prompt** (optional): Edit `pdfrag.R` to customize the summarization instructions

## 💻 Usage

### Basic Usage

```r
# Source the main script
source("pdfrag.R")

# The script will:
# 1. Load all PDFs from AMI_pdfs/
# 2. Process each paper with RAG
# 3. Generate summaries
# 4. Save output to test_papers_output.md
```

### Processing Function

The core `process_single_paper()` function handles:

```r
process_single_paper <- function(obj, id, total) {
  # 1. Reads PDF and chunks content
  # 2. Embeds chunks with nomic-embed-text
  # 3. Creates vector store for retrieval
  # 4. Generates summary with llama3.2
  # 5. Returns structured output
}
```

**Key Features**:

- **Chunk Limiting**: Caps at 200 chunks per paper to prevent memory issues
- **Batch Embedding**: Processes 25 chunks at a time with pauses
- **Retry Logic**: 3 attempts per batch with 5-second recovery periods
- **Progress Tracking**: Real-time feedback on processing status

### Output Format

Each paper summary includes:

1. **Type**: Review paper, case study, new method, or combination
2. **Paper Summary**: 1-2 paragraphs covering:
   - Research goals
   - Gap addressed
   - Challenges
   - Results
3. **Table** (if applicable): Standardized comparison table with:
   - Paper citation
   - Type of water use
   - Data resolution
   - Flow rate units
   - Number of homes
   - Goals
   - Methods
   - Results

## ⚙️ Configuration

### Adjust Memory Limits

In `process_single_paper.R`:

```r
# Reduce max chunks for low-memory systems
if (num_chunks > 100) {  # Changed from 200
  chunks <- chunks[1:100]
}

# Smaller batch size
batch_size <- 15  # Changed from 25
```

### Change Models

```r
# Use smaller embedding model
embed = \(x) embed_ollama(x, model = "all-minilm")

# Use different LLM
client <- chat_ollama(
  model = "mistral",  # or llama3.1, qwen2.5, etc.
  system_prompt = system_prompt,
  params = list(temperature = 0.1)
)
```

### Customize System Prompt

Edit the `system_prompt` variable in `pdfrag.R` to change:

- Output structure
- Focus areas
- Citation style
- Table columns

## 🛠️ Troubleshooting

### Ollama Crashes (HTTP 500 Error)

**Symptoms**: `HTTP 500 Internal Server Error` with `EOF`

**Solutions**:

1. Reduce chunk limit (line 18 in `process_single_paper.R`)
2. Decrease batch size (line 32)
3. Restart Ollama: `pkill ollama && ollama serve`
4. Switch to smaller models

### Model Doesn't Support Tools

**Symptoms**: `does not support tools` error

**Solution**: Use supported models:

- ✅ llama3.2, llama3.1, mistral, qwen2.5
- ❌ gemma3:12b (no tool support)

### Out of Memory

**Solutions**:

1. Process fewer PDFs at once
2. Add longer pauses between papers
3. Reduce `max_length` in `markdown_chunk()`

### Progress Bar Not Updating

Make sure `progressr` handlers are set:

```r
handlers(global = TRUE)
handlers("cli")
```

## 📊 Example Output

```markdown
# Paper Title Here

**Type:** New method

**Paper Summary:**
This study addresses the challenge of detecting outdoor watering events
using high-resolution smart meter data. The research gap involves...

**Table:**
| Paper | Type of Water Use | Data Resolution | Flow Rate Unit(s) | ...
|-------|-------------------|-----------------|-------------------|-----|
| Smith et al. 2024 | Outdoor irrigation | 1-minute | L/min | ... |
```

## 🤝 Contributing

This is a research tool. Feel free to adapt for your own literature review needs.

## 📝 Notes

- **Processing Time**: ~2-5 minutes per paper depending on length and system specs
- **Storage**: Temporary RAG stores are created and cleaned up automatically
- **Output**: Combined markdown saved to `test_papers_output.md`

## 📄 License

MIT License - See individual package licenses for dependencies.

## 👥 Authors

- Carson Slater
- Based on [ragnar tutorial by Steven P. Sanderson](https://www.spsanderson.com/steveondata/posts/2025-10-29/)

## 🔗 References

- [Ollama Documentation](https://github.com/ollama/ollama)
- [ragnar Package](https://github.com/mlverse/ragnar)
- [ellmer Package](https://github.com/hadley/ellmer)

---

**Last Updated**: November 2025
