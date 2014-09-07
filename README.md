# unjavadoc

Convert javadoc API documentation to Java source code stubs

Usage:

    ./unjd.pl javadocs-directory out-root

`out-root` will be populated with .java source files from the javadocs.
An `api.csv` comma-separated list of APIs will also be written,
usable with `fromcsv.pl` to generate the Java source (experimental).

## License

MIT

