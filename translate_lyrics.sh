#!/bin/bash

# Lyrics Translation Script using Glean
# Processes all languages and models to generate translations

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LYRICS_FILE="$SCRIPT_DIR/lyrics.txt"
PROMPT_FILE="$SCRIPT_DIR/prompt.txt"
MODELS_FILE="$SCRIPT_DIR/models.txt"
LANGUAGES_FILE="$SCRIPT_DIR/languages.txt"
OUTPUT_BASE_DIR="$SCRIPT_DIR/translations"

# Function to sanitize names for directories/files
sanitize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_\|_$//g'
}

# Function to sanitize model names for filenames
sanitize_model_name() {
    echo "$1" | sed 's/[\/:]/_/g' | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g' | sed 's/^_\|_$//g'
}

# Check if required files exist
for file in "$LYRICS_FILE" "$PROMPT_FILE" "$MODELS_FILE" "$LANGUAGES_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "Error: Required file not found: $file"
        exit 1
    fi
done

# Check if glean.py is available
if ! command -v glean.py &> /dev/null && [[ ! -f "./glean.py" ]]; then
    echo "Error: glean.py not found. Please ensure it's in PATH or current directory."
    exit 1
fi

# Determine glean command
GLEAN_CMD="glean.py"
if [[ -f "./glean.py" ]]; then
    GLEAN_CMD="./glean.py"
fi

# Create base output directory
mkdir -p "$OUTPUT_BASE_DIR"

# Read prompt template
PROMPT_TEMPLATE=$(cat "$PROMPT_FILE")

echo "Starting lyrics translation process..."
echo "Output directory: $OUTPUT_BASE_DIR"
echo "Using glean command: $GLEAN_CMD"
echo ""

# Process each language
while IFS= read -r language || [[ -n "$language" ]]; do
    # Skip empty lines and comments
    [[ -z "$language" || "$language" =~ ^[[:space:]]*# ]] && continue
    
    # Remove trailing dots and whitespace
    language=$(echo "$language" | sed 's/\.$//' | xargs)
    
    # Sanitize language name for directory
    lang_dir=$(sanitize_name "$language")
    lang_output_dir="$OUTPUT_BASE_DIR/$lang_dir"
    
    echo "Processing language: $language -> $lang_dir/"
    mkdir -p "$lang_output_dir"
    
    # Create language-specific prompt
    current_prompt=$(echo "$PROMPT_TEMPLATE" | sed "s/__LANGUAGE__/$language/g")
    
    # Process each model
    while IFS= read -r model || [[ -n "$model" ]]; do
        # Skip empty lines and comments
        [[ -z "$model" || "$model" =~ ^[[:space:]]*# ]] && continue
        
        # Remove whitespace
        model=$(echo "$model" | xargs)
        
        # Sanitize model name for filename
        model_filename=$(sanitize_model_name "$model")
        output_file="$lang_output_dir/${model_filename}.txt"
        
        echo "  Processing model: $model -> ${model_filename}.txt"
        
        # Check if file already exists
        if [[ -f "$output_file" ]]; then
            echo "    ⏭ Skipping - file already exists"
            continue
        fi
        
        # Run glean with the current model and prompt
        if cat "$LYRICS_FILE" | $GLEAN_CMD --model "$model" --prompt "$current_prompt" > "$output_file" 2>/dev/null; then
            echo "    ✓ Success"
        else
            echo "    ✗ Failed - removing empty file"
            rm -f "$output_file"
        fi
        
    done < "$MODELS_FILE"
    
    echo ""
    
done < "$LANGUAGES_FILE"

echo "Translation process completed!"
echo "Results saved in: $OUTPUT_BASE_DIR"
echo ""
echo "Directory structure:"
find "$OUTPUT_BASE_DIR" -type f -name "*.txt" | head -10
if [[ $(find "$OUTPUT_BASE_DIR" -type f -name "*.txt" | wc -l) -gt 10 ]]; then
    echo "... and $(( $(find "$OUTPUT_BASE_DIR" -type f -name "*.txt" | wc -l) - 10 )) more files"
fi
