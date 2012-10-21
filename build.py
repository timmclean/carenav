#!/usr/bin/env python

import shutil
import os
import glob
import subprocess

# Config
LESSC = 'lessc'
COFFEEC = 'coffee'
PEGJSC = 'pegjs'
INPUT_DIR = 'source'
OUTPUT_DIR = 'build'

def run():
	COMPILERS = [compileCoffeeScript, compileLESS, compilePEGJS]

	# Remove existing build
	if os.path.exists(OUTPUT_DIR):
		print('Clearing out previous build...')
		shutil.rmtree(OUTPUT_DIR)

	# Copy to output directory
	print('Duplicating source tree...')
	shutil.copytree(INPUT_DIR, OUTPUT_DIR)

	# Run compilers on each file
	print('Processing source...')
	for srcFilePath in iterateFileTree(OUTPUT_DIR):
		# Process files as many times as necessary
		rerunNeeded = True
		while rerunNeeded:
			# Default to running only once
			rerunNeeded = False

			# Try all of the compilers
			for c in COMPILERS:
				try:
					srcFilePath = c(srcFilePath)
					rerunNeeded = True
					break
				except InappropriateCompilerException:
					pass

	# TODO Minify
	print('Build successful.')

def iterateFileTree(rootDir):
	for root, dirs, files in os.walk(rootDir):
		for f in files:
			yield os.path.join(root, f)

class InappropriateCompilerException(Exception):
	pass

def compileCoffeeScript(srcFilePath):
	if not srcFilePath.endswith('.coffee'):
		raise InappropriateCompilerException()

	# Determine new file name
	dstFilePath = replaceSuffix(srcFilePath, '.coffee', '.js')
	print(srcFilePath + ' -> ' + dstFilePath)

	# Compile
	resultCode = subprocess.call([COFFEEC, '-c', srcFilePath])

	# Delete old file
	os.remove(srcFilePath)

	# Check for error code
	if resultCode != 0:
		raise Exception('CoffeeScript compilation failed for ' + srcFilePath)

	return dstFilePath

def compileLESS(srcFilePath):
	if not srcFilePath.endswith('.less'):
		raise InappropriateCompilerException()

	# Determine new file name
	dstFilePath = replaceSuffix(srcFilePath, '.less', '.css')
	print(srcFilePath + ' -> ' + dstFilePath)

	# Compile
	resultCode = subprocess.call([LESSC, srcFilePath, dstFilePath])

	# Delete old file
	os.remove(srcFilePath)

	# Check for error code
	if resultCode != 0:
		raise Exception('LESS compilation failed for ' + srcFilePath)

	return dstFilePath

def compilePEGJS(srcFilePath):
	if not srcFilePath.endswith('.pegjs'):
		raise InappropriateCompilerException()

	# Determine new file name
	dstFilePath = replaceSuffix(srcFilePath, '.pegjs', '.js')
	print(srcFilePath + ' -> ' + dstFilePath)

	# Compile
	resultCode = subprocess.call([PEGJSC, '--cache', srcFilePath, dstFilePath])

	# Delete old file
	os.remove(srcFilePath)

	# Check for error code
	if resultCode != 0:
		raise Exception('PEGJS compilation failed for ' + srcFilePath)

	return dstFilePath

def replaceSuffix(string, old, new):
	# Assumes suffix is present
	return string[:-len(old)] + new

if __name__ == '__main__':
	run()
