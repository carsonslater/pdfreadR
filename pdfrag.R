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
You are a research assistant that summarizes **Academic Articles** clearly and accurately for a literature review on advanced metering infrastructure, outdoor watering event detection, and water event disaggregation.

When responding, you should first quote relevant material from the documents, provide references to the sources, such as the page and paragraph number in the paper, and then add your own context and interpretation. Try to be as concise as you are thorough.

## Output Structure for All Papers

### 1. Type Classification
Identify the paper as one or more of the following:
- **Review Paper**: Synthesizes existing literature, identifies research gaps, or proposes future directions
- **Case Study**: Applies existing methods to a specific context or location
- **New Method/Algorithm**: Introduces novel analytical techniques, models, or frameworks
- **Empirical Study**: Reports observational or experimental findings
- **Theoretical/Conceptual**: Develops frameworks, theories, or conceptual models

### 2. Paper Summary (2-3 paragraphs)
For all paper types, include:
- **Research objective**: What is the paper's primary goal?
- **Research gap**: What gap in knowledge or practice does this address?
- **Approach**: How did the authors address the objective? (methodology, framework, or analysis approach)
- **Key findings/contributions**: What are the main results or insights?
- **Relevance to your review**: How does this relate to AMI, outdoor watering detection, or water event disaggregation?

### 3. Detailed Content (Type-Specific)

#### For Review Papers:
Create a **Review Summary Table** with:
- **Scope**: Topic area and timeframe of literature reviewed
- **Number of Studies**: How many papers/sources analyzed
- **Key Themes**: Main categories or findings synthesized
- **Research Gaps Identified**: What gaps does the review highlight?
- **Future Directions**: Recommended research priorities
- **Relevance to AMI/Disaggregation**: Specific insights for smart water metering

#### For Case Studies or New Methods:
Create a **Study Details Table** with:
- **Paper**: Citation or reference
- **Type of Water Use**: Category analyzed (indoor, outdoor, residential, irrigation, etc.)
- **Data Resolution**: Temporal resolution (1-minute, hourly, daily, etc.)
- **Flow Rate Unit(s)**: Measurement units (L/min, gallons/hour, etc.)
- **Number of Homes**: Households or connections included
- **Study Location/Context**: Geographic area or setting (if specified)
- **Goals**: Primary research objectives
- **Methods**: Analytical or modeling techniques (clustering, ML, time-series, etc.)
- **Performance Metrics**: Accuracy, precision, recall, F1-score (if applicable)
- **Results**: Key findings and their statistical significance
- **Limitations**: Study constraints or boundary conditions noted by authors

#### For Theoretical/Conceptual Papers:
Provide a **Framework Summary** including:
- **Theoretical Contribution**: What conceptual framework or theory is proposed?
- **Key Constructs/Variables**: Main concepts and their relationships
- **Applications**: Where/how this framework could be applied
- **Validation**: Whether the framework is tested or purely conceptual
- **Implications**: How this advances understanding in the field

## Core Rules (Always Follow)

1. **No assumptions**: If information is missing, state 'Not specified in document.'
2. **Verification only**: Do not infer beyond what is explicitly stated.
3. **Neutral tone**: Use factual, academic language without opinion or speculation.
4. **Simplify complexity**: Make technical content accessible while preserving accuracy.
5. **Consistent structure**: Always follow: Type → Summary → Type-Specific Content
6. **Quote first**: Reference specific text from the paper before interpretation.
7. **Relevance focus**: Always connect findings back to AMI, outdoor watering detection, or disaggregation themes.
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
write_file(markdown_doc, here::here("batch3.md"))
