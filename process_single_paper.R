process_single_paper <- function(obj, id, total) {
  file_path <- obj |> pull(1) |> pluck(1)
  file_name <- obj |> pull(file_name) |> pluck(1)

  cat(sprintf("\n[%d/%d] Processing: %s\n", id, total, file_name))

  tryCatch(
    {
      store_location <- paste0("pdf_ragnar_duckdb_", id)

      # Read and chunk the document first
      chunks <- file_path |> read_as_markdown() |> markdown_chunk()
      num_chunks <- length(chunks)
      cat(sprintf("  Found %d chunks\n", num_chunks))

      # CRITICAL: Limit chunk size if too many
      if (num_chunks > 200) {
        cat(sprintf(
          "  ⚠️  Large file detected (%d chunks), taking first 200 chunks\n",
          num_chunks
        ))
        chunks <- chunks[1:200]
        num_chunks <- 200
      }

      # Create store
      store <- ragnar_store_create(
        store_location,
        embed = \(x) embed_ollama(x, model = "nomic-embed-text:latest"),
        overwrite = TRUE
      )

      # Insert chunks in small batches with retry logic
      batch_size <- 25 # Smaller batches to prevent Ollama crashes
      num_batches <- ceiling(num_chunks / batch_size)

      for (i in 1:num_batches) {
        start_idx <- (i - 1) * batch_size + 1
        end_idx <- min(i * batch_size, num_chunks)
        batch <- chunks[start_idx:end_idx]

        cat(sprintf(
          "  Embedding batch %d/%d (chunks %d-%d)...\n",
          i,
          num_batches,
          start_idx,
          end_idx
        ))

        # Retry logic for batch insertion
        max_retries <- 3
        success <- FALSE

        for (attempt in 1:max_retries) {
          tryCatch(
            {
              ragnar_store_insert(store, batch)
              success <- TRUE
              break
            },
            error = function(e) {
              if (attempt < max_retries) {
                cat(sprintf(
                  "    ⚠️  Batch failed (attempt %d/%d), retrying in 5s...\n",
                  attempt,
                  max_retries
                ))
                Sys.sleep(5) # Wait for Ollama to recover
              } else {
                stop(sprintf(
                  "Failed to embed batch after %d attempts: %s",
                  max_retries,
                  e$message
                ))
              }
            }
          )
        }

        if (!success) {
          stop(sprintf("Could not process batch %d", i))
        }

        # Give Ollama a breather between batches
        if (i < num_batches) {
          Sys.sleep(2)
        }
      }

      cat("  Building index...\n")
      ragnar_store_build_index(store)

      # Create client and chat
      client <- chat_ollama(
        model = "llama3.2",
        system_prompt = system_prompt,
        params = list(temperature = 0.1)
      )

      ragnar_register_tool_retrieve(chat = client, store = store)
      user_prompt <- glue("Please summarize the paper: {file_path}")

      cat("  Generating summary...\n")
      res <- client$chat(user_prompt, echo = "all")

      rec <- obj |> mutate(llm_resp = res)

      # Clean up store
      unlink(store_location, recursive = TRUE)

      cat(sprintf("  ✓ Successfully processed %s\n", file_name))
      return(rec)
    },
    error = function(e) {
      cat(sprintf("  ❌ ERROR: %s\n", e$message))

      # Clean up if store was created
      store_location <- paste0("pdf_ragnar_duckdb_", id)
      if (dir.exists(store_location)) {
        unlink(store_location, recursive = TRUE)
      }

      return(obj |> mutate(llm_resp = paste("ERROR:", e$message)))
    }
  )
}
