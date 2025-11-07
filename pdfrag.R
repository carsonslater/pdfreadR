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


  **Model Behavior Rules:**

  * If information is missing, state “Not specified in document.”
  * Do not infer or assume; summarize only verifiable content.
  * Maintain neutral, factual tone using payer-standard language (e.g., “medically necessary,” “experimental/investigational”).
  * Simplify complex clinical text while preserving accuracy.
  * Always follow the structure: **Paper Genre → Paper Summary → Table (If Applicable).**
  * Avoid opinion, speculation, or advice; ensure compliance-focused clarity.
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

output_tbl <- list_rbind(llm_resp_list) |>
  mutate(
    email_body = md(glue(
      "
      Please see summary for below:

      Name: {file_name}

      Extension: {file_extension}

      Size: {file_size} bytes

      Summary Response:

      {llm_resp}
    "
    ))
  )

row_to_md <- function(row) {
  glue::glue(
    "
# {row$file_name}

**Extension:** {row$file_extension}
**Size:** {row$file_size}
**Modified:** {row$file_date}

## Summary

{row$llm_resp}
  "
  )
}

markdown_sections <- map_chr(1:nrow(output_tbl), function(i) {
  row_to_md(output_tbl[i, ])
})
markdown_doc <- paste(markdown_sections, collapse = "\n---\n")
write_file(markdown_doc, here::here("test_papers_output.md"))

# Depracated Code --------------------------------------------------------

# VERSION 1.0
# llm_resp_list <- with_progress({
#   p <- progressor(along = file_split_tbl)

#   file_split_tbl[1:3] |>
#     imap(
#       .f = function(obj, id) {
#         file_path <- obj |> pull(1) |> pluck(1)
#         file_name <- obj |> pull(file_name) |> pluck(1)

#         p(sprintf("Processing %s", file_name)) # Update progress

#         store_location <- "pdf_ragnar_duckdb"
#         store <- ragnar_store_create(
#           store_location,
#           embed = \(x) embed_ollama(x, model = "nomic-embed-text:latest"),
#           overwrite = TRUE
#         )
#         chunks <- file_path |>
#           read_as_markdown() |>
#           markdown_chunk()
#         ragnar_store_insert(store, chunks)
#         ragnar_store_build_index(store)
#         client <- chat_ollama(
#           model = "llama3.2",
#           system_prompt = system_prompt,
#           params = list(temperature = 0.1)
#         )
#         ragnar_register_tool_retrieve(chat = client, store = store)
#         user_prompt <- glue("Please summarize the paper: {file_path}")
#         res <- client$chat(user_prompt, echo = "all")
#         rec <- obj |> mutate(llm_resp = res)
#         return(rec)
#       }
#     )
# })

# VERSION 1.1
# llm_resp_list <- with_progress({
#   p <- progressor(along = file_split_tbl)

#   file_split_tbl |>
#     imap(function(obj, id) {
#       file_path <- obj |> pull(1) |> pluck(1)
#       file_name <- obj |> pull(file_name) |> pluck(1)

#       p(sprintf("Processing %s", file_name))

#       # This tryCatch is what makes it continue
#       tryCatch(
#         {
#           store_location <- paste0("pdf_ragnar_duckdb_", id)
#           store <- ragnar_store_create(
#             store_location,
#             embed = \(x) embed_ollama(x, model = "nomic-embed-text:latest"),
#             overwrite = TRUE
#           )

#           chunks <- file_path |> read_as_markdown() |> markdown_chunk()
#           ragnar_store_insert(store, chunks)
#           ragnar_store_build_index(store)

#           client <- chat_ollama(
#             model = "llama3.2",
#             system_prompt = system_prompt,
#             params = list(temperature = 0.1)
#           )

#           ragnar_register_tool_retrieve(chat = client, store = store)
#           user_prompt <- glue("Please summarize the paper: {file_path}")
#           res <- client$chat(user_prompt, echo = "all")

#           obj |> mutate(llm_resp = res)
#         },
#         error = function(e) {
#           # Instead of stopping, return error message
#           cat(sprintf("\n❌ Failed: %s - %s\n", file_name, e$message))
#           obj |> mutate(llm_resp = paste("ERROR:", e$message))
#         }
#       )
#     })
# })
