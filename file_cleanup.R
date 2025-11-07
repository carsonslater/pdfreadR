# Carson Slater ----------------------------------------------------------
#
# Date Create: November 7, 2025
# Description: Takes a Zotero exported RDF library and retrieves all of the
# pdfs from it, and places them all in one folder.
#
# ------------------------------------------------------------------------

library("fs")

# Path to your exported Zotero collection
zotero_export_dir <- here::here("AMI_Papers", "files")

# Path to the new single-folder destination
rag_pdf_dir <- here::here("AMI_pdfs")
dir_create(rag_pdf_dir)

# Find all PDFs recursively (ignore HTML, etc.)
pdfs <- dir_ls(zotero_export_dir, recurse = TRUE, glob = "*.pdf")

# Copy all PDFs into the single folder
file_copy(pdfs, rag_pdf_dir, overwrite = TRUE)

# Optional: preview copied files
names <- tibble(file_name = path_file(pdfs))
