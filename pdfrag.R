# Carson Slater ----------------------------------------------------------
#
# Date Created: November 7, 2025
# Description: A script to set up RAG for Literature Reviews on Papers.
# This is based off a past found at this link:
# https://www.spsanderson.com/steveondata/posts/2025-10-29/
#
# ------------------------------------------------------------------------

# Colophon ---------------------------------------------------------------

library("ragnar")
library("ellmer")
library("fs")
library("tidyverse")
library("glue")
library('blastula')
library("progressr")
# library(RDCOMClient)

source(here::here("process_single_paper.R"))

# Read In Files ----------------------------------------------------------

papers_files_path <- here::here("AMI_pdfs")
papers_files <- list.files(papers_files_path, full.names = TRUE)

# System Prompt ----
system_prompt <- str_squish(
  "
  You are an research assistant that summarizes **Academic Articles** clearly and accurately for a literature review on advanced metering infrastructure, outdoor watering event detection, and water event disaggregation.

  When responding, you should first quote relevant material from the documents in the store,
  provide links to the sources, and then add your own context and interpretation. Try to be as concise
  as you are thorough.

  For every document passed to you the output should if applicable include:

  1. Type: A sentence describing if the paper is a review paper, a case study, a new method, or a combination of these.
  2. Paper Summary: 1–2 paragraphs describing the goal of the paper, what research gap this paper addresses, the challenges (if any), and the results.
  3. A Table: If the paper is a case study, or a new method, then include a table filling in the information corresponding to the columns in the list below.

    * **Paper** – Citation or reference for the study being summarized.
    * **Type of Water Use** – Category of usage analyzed (e.g., indoor, outdoor, residential, irrigation).
    * **Data Resolution** – Temporal granularity of the smart meter data (e.g., 1-minute, hourly, daily).
    * **Flow Rate Unit(s)** – Units used to measure water flow (e.g., L/min, gallons/hour).
    * **Number of Homes** – Total number of households or connections included in the study.
    * **Goals** – Primary research objectives or questions addressed in the study.
    * **Methods** – Analytical or modeling techniques applied (e.g., clustering, regression, time-series analysis).
    * **Results** – Key findings or conclusions derived from the study’s analysis.


  As the helpful research assistant, these are the rules that you should always follow:

  1. If information is missing, state “Not specified in document.”
  2. Do not infer or assume; summarize only verifiable content.
  3. Maintain neutral, factual tone using payer-standard language (e.g., “medically necessary,” “experimental/investigational”).
  4. Simplify complex clinical text while preserving accuracy.
  5. Always follow the structure: **Paper Genre → Paper Summary → Table (If Applicable).**
  6. Avoid opinion, speculation, or advice; ensure compliance-focused clarity.
  "
)


file_split_tbl <- tibble(
  file_path = papers_files
) |>
  mutate(
    file_name = path_file(file_path),
    file_extension = path_ext(file_path),
    file_size = file_size(file_path),
    file_date = file_info(file_path)$modification_time
  ) |>
  group_split(file_name)

# Progress Bar ----
handlers(global = TRUE)
handlers("cli")


# LLM Response List ----
library(progressr)

# Add this before your imap call
handlers(global = TRUE)
handlers("cli") # or handlers("txtprogressbar") for a simpler bar

llm_resp_list <- with_progress({
  p <- progressor(along = file_split_tbl)

  file_split_tbl |> # Process ALL files, not just [1:3]
    imap(function(obj, id) {
      p(sprintf("Processing %d/%d", id, length(file_split_tbl)))

      result <- process_single_paper(obj, id, length(file_split_tbl))

      # Longer pause between papers to let Ollama fully recover
      if (id < length(file_split_tbl)) {
        cat("\n  Pausing 5 seconds before next paper...\n")
        Sys.sleep(5)
      }

      return(result)
    })
})

llm_resp_list_clean <- map(llm_resp_list, \(df) {
  df |> mutate(llm_resp = as.character(llm_resp))
})

output_tbl <- bind_rows(llm_resp_list_clean)

# Use pmap to iterate over rows more elegantly
markdown_sections <- output_tbl |>
  pmap_chr(function(
    file_name,
    file_extension,
    file_size,
    file_date,
    llm_resp,
    ...
  ) {
    glue::glue(
      "
# {file_name}

**Extension:** {file_extension}
**Size:** {file_size}
**Modified:** {format(file_date, '%Y-%m-%d %H:%M:%S')}

## Summary

{llm_resp}
      "
    )
  })

markdown_doc <- paste(markdown_sections, collapse = "\n\n---\n\n")
write_file(markdown_doc, here::here("test_papers_output.md"))
