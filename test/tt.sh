#!/bin/bash
gcc `gnustep-config --objc-flags` -w main.m Library.m Book.m Author.m BooksToAuthors.m Persist.m -o main -L/usr/lib -lgnustep-base
