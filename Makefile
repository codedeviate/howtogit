.PHONY: all git gh stubs lint clean

all: git gh

git:
	./scripts/build-book.sh git

gh:
	./scripts/build-book.sh gh

stubs:
	./scripts/make-stubs.sh git
	./scripts/make-stubs.sh gh

lint:
	./scripts/lint-chapters.sh git
	./scripts/lint-chapters.sh gh

clean:
	rm -rf dist
