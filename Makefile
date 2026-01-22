# Target PDF
TARGET = main.pdf

# All .tex files and .png files in the directory
TEX_FILES = $(wildcard *.tex)
PNG_FILES = $(wildcard *.png)

# Use latexmk to compile the document
$(TARGET): $(TEX_FILES) $(PNG_FILES)
	latexmk -pdf -pvc -interaction=nonstopmode main.tex

# Clean up auxiliary files
clean:
	latexmk -C
