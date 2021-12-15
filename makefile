SHELL = /usr/bin/env bash

_python ?= python
# for bump2version, valid options are: major, minor, patch
PART ?= patch

PANDOC = pandoc
pandocArgs = --toc -M date="`date "+%B %e, %Y"`" --filter=pantable --wrap=none
RSTs = CHANGELOG.rst README.rst docs/example-output.rst

# Main Targets #################################################################

.PHONY: docs api html test clean

docs: $(RSTs)
	$(MAKE) html
api: docs/api/
html: dist/docs/

test:
	rm -f .coverage*
	coverage run -m pytest -vv \
		tests
	coverage combine
	coverage report
	coverage html

clean:
	rm -f $(RSTs) .coverage* tests/model-latex.pdf tests/model-html.html

# docs #########################################################################

README.rst: docs/README.md docs/badges.csv
	printf \
		"%s\n\n" \
		".. This is auto-generated from \`$<\`. Do not edit this file directly." \
		> $@
	cd $(<D); \
	$(PANDOC) $(pandocArgs) $(<F) -V title='pantable Documentation' -s -t rst \
		>> ../$@

%.rst: %.md
	printf \
		"%s\n\n" \
		".. This is auto-generated from \`$<\`. Do not edit this file directly." \
		> $@
	$(PANDOC) $(pandocArgs) $< -s -t rst >> $@

docs/api/:
	sphinx-apidoc \
		--maxdepth 6 \
		--force \
		--separate \
		--module-first \
		--implicit-namespaces \
		--doc-project API \
		--output-dir $@ src/amsthm

dist/docs/:
	sphinx-build -E -b dirhtml docs dist/docs
	# sphinx-build -b linkcheck docs dist/docs

# maintenance ##################################################################

.PHONY: pypi pypiManual gh-pages pep8 flake8 pylint
# Deploy to PyPI
## by CI, properly git tagged
pypi:
	git push origin v1.2.3
## Manually
pypiManual:
	rm -rf dist
	poetry build
	twine upload dist/*

gh-pages:
	ghp-import --no-jekyll --push dist/docs

# check python styles
pep8:
	pycodestyle . --ignore=E501
flake8:
	flake8 . --ignore=E501
pylint:
	pylint amsthm

print-%:
	$(info $* = $($*))

# poetry #######################################################################

setup.py:
	poetry build
	cd dist; tar -xf amsthm-1.2.3.tar.gz amsthm-1.2.3/setup.py
	mv dist/amsthm-1.2.3/setup.py .
	rm -rf dist/amsthm-1.2.3

.PHONY: editable
# since poetry doesn't support editable, we can build and extract the setup.py,
# temporary remove pyproject.toml and ask pip to install from setup.py instead.
editable: setup.py
	mv pyproject.toml .pyproject.toml
	$(_python) -m pip install --no-dependencies -e .
	mv .pyproject.toml pyproject.toml

# releasing ####################################################################

.PHONY: bump
bump:
	bump2version $(PART)
	git push --follow-tags

# test files ###################################################################

demo: tests/model-latex.pdf tests/model-html.html

tests/model-latex.tex: tests/model-source.md
	pandoc -F amsthm $< -o $@ --top-level-division=chapter --toc -N
tests/model-latex.pdf: tests/model-source.md
	pandoc -F amsthm $< -o $@ --top-level-division=chapter --toc -N
tests/model-html.html: tests/model-source.md
	pandoc -F amsthm $< -o $@ --toc -N -s
