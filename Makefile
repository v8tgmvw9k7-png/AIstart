RSCRIPT ?= Rscript

.PHONY: all report demo test

# RStudio Build All starts the Shiny web server.
all:
	"$(RSCRIPT)" start.R

report:
	"$(RSCRIPT)" run.R

demo:
	"$(RSCRIPT)" run.R --demo

test:
	"$(RSCRIPT)" tests/test.R
	"$(RSCRIPT)" tests/web.R
