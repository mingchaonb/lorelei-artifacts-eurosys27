#pragma once

#include <cstdarg>

#include <lorelei/DLCall/Tools/VariadicArgDefs.h>
#include <lorelei/ThunkInterface/PassTags.h>
#include <lorelei/ThunkInterface/Proc.h>

extern "C" {
#include "jansson.h"
}

namespace lore::thunk::jansson_detail {

    class FormatScanner {
    public:
        explicit FormatScanner(const char *format) : m_current(format ? format : "") {
        }

        char peek() {
            skipIgnored();
            return *m_current;
        }

        char take() {
            char token = peek();
            if (token) {
                ++m_current;
            }
            return token;
        }

    private:
        void skipIgnored() {
            while (*m_current == ' ' || *m_current == '\t' || *m_current == '\n' ||
                   *m_current == ',' || *m_current == ':') {
                ++m_current;
            }
        }

        const char *m_current;
    };

    class VargWriter {
    public:
        VargWriter(va_list arguments, CVargEntry *output) : m_output(output) {
            va_copy(m_arguments, arguments);
        }

        ~VargWriter() {
            va_end(m_arguments);
            m_output[m_count] = {};
        }

        template <class T>
        void take() {
            m_output[m_count++] = CVargGet(va_arg(m_arguments, T));
        }

    private:
        va_list m_arguments;
        CVargEntry *m_output;
        size_t m_count = 0;
    };

    inline void extractPackString(FormatScanner &scanner, VargWriter &writer) {
        if (scanner.peek() == '?' || scanner.peek() == '*') {
            scanner.take();
        }
        writer.take<const char *>();
        if (scanner.peek() == '#') {
            scanner.take();
            writer.take<int>();
        } else if (scanner.peek() == '%') {
            scanner.take();
            writer.take<size_t>();
        }
        while (scanner.peek() == '+') {
            scanner.take();
            writer.take<const char *>();
            if (scanner.peek() == '#') {
                scanner.take();
                writer.take<int>();
            } else if (scanner.peek() == '%') {
                scanner.take();
                writer.take<size_t>();
            }
        }
    }

    inline bool extractPackValue(FormatScanner &scanner, VargWriter &writer) {
        switch (scanner.take()) {
            case '{':
                while (scanner.peek() && scanner.peek() != '}') {
                    if (scanner.take() != 's') {
                        return false;
                    }
                    extractPackString(scanner, writer);
                    if (!extractPackValue(scanner, writer)) {
                        return false;
                    }
                }
                return scanner.take() == '}';
            case '[':
                while (scanner.peek() && scanner.peek() != ']') {
                    if (!extractPackValue(scanner, writer)) {
                        return false;
                    }
                }
                return scanner.take() == ']';
            case 's':
                extractPackString(scanner, writer);
                return true;
            case 'b':
            case 'i':
                writer.take<int>();
                return true;
            case 'I':
                writer.take<json_int_t>();
                return true;
            case 'f':
                writer.take<double>();
                return true;
            case 'O':
            case 'o':
                if (scanner.peek() == '?' || scanner.peek() == '*') {
                    scanner.take();
                }
                writer.take<json_t *>();
                return true;
            case 'n':
                return true;
            default:
                return false;
        }
    }

    inline bool extractUnpackValue(FormatScanner &scanner, VargWriter &writer,
                                   bool validateOnly) {
        switch (scanner.take()) {
            case '{':
                while (scanner.peek() && scanner.peek() != '}') {
                    if (scanner.peek() == '!' || scanner.peek() == '*') {
                        scanner.take();
                        continue;
                    }
                    if (scanner.take() != 's') {
                        return false;
                    }
                    writer.take<const char *>();
                    if (scanner.peek() == '?') {
                        scanner.take();
                    }
                    if (!extractUnpackValue(scanner, writer, validateOnly)) {
                        return false;
                    }
                }
                return scanner.take() == '}';
            case '[':
                while (scanner.peek() && scanner.peek() != ']') {
                    if (scanner.peek() == '!' || scanner.peek() == '*') {
                        scanner.take();
                        continue;
                    }
                    if (!extractUnpackValue(scanner, writer, validateOnly)) {
                        return false;
                    }
                }
                return scanner.take() == ']';
            case 's':
                if (!validateOnly) {
                    writer.take<const char **>();
                    if (scanner.peek() == '%') {
                        scanner.take();
                        writer.take<size_t *>();
                    }
                } else if (scanner.peek() == '%') {
                    scanner.take();
                }
                return true;
            case 'i':
            case 'b':
                if (!validateOnly) {
                    writer.take<int *>();
                }
                return true;
            case 'I':
                if (!validateOnly) {
                    writer.take<json_int_t *>();
                }
                return true;
            case 'f':
            case 'F':
                if (!validateOnly) {
                    writer.take<double *>();
                }
                return true;
            case 'O':
            case 'o':
                if (!validateOnly) {
                    writer.take<json_t **>();
                }
                return true;
            case 'n':
                return true;
            default:
                return false;
        }
    }

    /// PackExtractor - Boxes the arguments described by Jansson's packing grammar.
    struct PackExtractor {
        static void extract(const char *format, va_list arguments, CVargEntry *output) {
            FormatScanner scanner(format);
            VargWriter writer(arguments, output);
            extractPackValue(scanner, writer);
        }
    };

    /// PackExExtractor - Handles the fixed error and flags arguments of json_pack_ex.
    struct PackExExtractor {
        static void extract(json_error_t *, size_t, const char *format, va_list arguments,
                            CVargEntry *output) {
            PackExtractor::extract(format, arguments, output);
        }
    };

    /// UnpackExtractor - Boxes output pointers described by Jansson's unpacking grammar.
    struct UnpackExtractor {
        static void extract(json_t *, const char *format, va_list arguments,
                            CVargEntry *output) {
            FormatScanner scanner(format);
            VargWriter writer(arguments, output);
            extractUnpackValue(scanner, writer, false);
        }
    };

    /// UnpackExExtractor - Honors JSON_VALIDATE_ONLY while parsing json_unpack_ex arguments.
    struct UnpackExExtractor {
        static void extract(json_t *, json_error_t *, size_t flags, const char *format,
                            va_list arguments, CVargEntry *output) {
            FormatScanner scanner(format);
            VargWriter writer(arguments, output);
            extractUnpackValue(scanner, writer, (flags & JSON_VALIDATE_ONLY) != 0);
        }
    };

}

namespace lore::thunk {

    template <>
    struct ProcFnDesc<::json_pack> {
        _DESC pass::custom_variadic<jansson_detail::PackExtractor, 1, 2> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::json_pack_ex> {
        _DESC pass::custom_variadic<jansson_detail::PackExExtractor, 3, 4> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::json_unpack> {
        _DESC pass::custom_variadic<jansson_detail::UnpackExtractor, 2, 3> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::json_unpack_ex> {
        _DESC pass::custom_variadic<jansson_detail::UnpackExExtractor, 4, 5> builder_pass = {};
    };

}
