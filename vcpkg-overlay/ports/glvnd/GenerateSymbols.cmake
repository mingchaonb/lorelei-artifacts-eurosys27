foreach(required_variable IN ITEMS NM INPUT_LIBRARY EXTRA_SYMBOLS OUTPUT_FILE)
    if(NOT DEFINED ${required_variable})
        message(FATAL_ERROR "GenerateSymbols.cmake requires ${required_variable}")
    endif()
endforeach()

execute_process(
    COMMAND "${NM}" -D --defined-only "${INPUT_LIBRARY}"
    RESULT_VARIABLE nm_status
    OUTPUT_VARIABLE nm_output
    ERROR_VARIABLE nm_error
)
if(NOT nm_status EQUAL 0)
    message(FATAL_ERROR "nm failed for ${INPUT_LIBRARY}: ${nm_error}")
endif()

set(symbols "")
string(REPLACE "\n" ";" nm_lines "${nm_output}")
foreach(line IN LISTS nm_lines)
    if(line MATCHES "^[0-9A-Fa-f]+ +[TW] +([^@ ]+)$")
        list(APPEND symbols "${CMAKE_MATCH_1}")
    endif()
endforeach()

file(STRINGS "${EXTRA_SYMBOLS}" extra_lines)
foreach(line IN LISTS extra_lines)
    string(STRIP "${line}" line)
    if(NOT line STREQUAL "" AND NOT line MATCHES "^#" AND NOT line MATCHES "^\\[")
        list(APPEND symbols "${line}")
    endif()
endforeach()

list(REMOVE_DUPLICATES symbols)
list(SORT symbols)
string(REPLACE ";" "\n" symbol_text "${symbols}")
file(WRITE "${OUTPUT_FILE}" "[Function]\n${symbol_text}\n")
