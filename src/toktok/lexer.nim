import std/[lexbase, streams, macros]
from std/strutils import `%`, replace, indent, toUpperAscii, startsWith
from std/sequtils import toSeq

export lexbase, streams

# {.experimental: "caseStmtMacros".}

let
    lexer_object_ident {.compileTime.} = newLit("Lexer")
    lexer_param_ident {.compileTime.} = newLit("lex")
    lexer_exception_ident {.compileTime.} = newLit("LexerException")

    template_hasError_ident {.compileTime.} = newLit("hasError")
    proc_getError_ident {.compileTime.} = newLit("getError")

    enum_token_ident {.compileTime.} = newLit("TokenKind")
    token_tuple_ident {.compileTime.} = newLit("TokenTuple")
    tkPrefix {.compileTime.} = newLit("tk_")
    tkUnknown {.compileTime.} = newLit("TK_UNKNOWN")
    tkIdentifier {.compileTime.} = newLit("TK_IDENTIFIER")
    tkEOF {.compileTime.} = newLit("TK_EOF")

var 
    prefIncludeWhitespaces {.compileTime.} = false
    prefPromptTokens {.compileTime.} = false
    prefPrefixTokens {.compileTime.} = "TK_"
    prefUppercaseTokens {.compileTime.} = true

macro toktokSettings*(
    includeWhitespaces, promptTokens, uppercaseTokens: static bool,
    prefixTokens: static string) =
    # whether to list tokens on compile time via cli
    prefPromptTokens = promptTokens
    # tokenize whitespaces or count as integer
    prefIncludeWhitespaces = includeWhitespaces
    # add a prefix 
    prefPrefixTokens = prefixTokens
    # transform tokens to uppercaseAscii
    prefUppercaseTokens = uppercaseTokens

macro tokens*(tks: untyped) =
    ## Generate TokenKind enumeration based on given identifiers and keys.
    ## Keys can be `int`, `char` or `string` and are used for creating
    ## the main `case statement` of your lexer
    echo "✨ TokTok successfully compiled\n"
    tks.expectKind(nnkStmtList)
    result = nnkStmtList.newTree()

    var enumTokensNode = newNimNode(nnkEnumTy)
    # var caseTokens = newNimNode(nnkCaseStmt)
    var caseStrTokens: seq[tuple[strToken: string, tokToken: string]]
    var caseCharTokens: seq[tuple[charToken: char, tokToken: string]]
    enumTokensNode.add(newEmptyNode())
    
    # add TK_UNKNOWN at the begining of TokenKind enum
    var tkIdent = newIdentNode(toUpperAscii(tkUnknown.strVal))
    enumTokensNode.add(tkIdent)
    
    for tk in tks:
        # tk.expectKind(nnkIdent)
        if tk.kind == nnkIdent:
            tkIdent = newIdentNode(toUpperAscii(tkPrefix.strVal & tk.strVal))
            enumTokensNode.add(tkIdent)
        elif tk.kind == nnkInfix:
            tkIdent = newIdentNode(toUpperAscii(tkPrefix.strVal & tk[1].strVal))
            enumTokensNode.add(tkIdent)
            if tk[2].kind == nnkStrLit:
                # handle string based tokens
                if prefPromptTokens == true:
                    echo "\n  Token:", indent(tk[1].strVal, 7), "\n  Keyword:", indent(tk[2].strVal, 5)
                caseStrTokens.add((strToken: tk[2].strVal, tokToken: tk[1].strVal))
            elif tk[2].kind == nnkInfix:
                let infixStr = tk[2][0].strVal
                if tk[2][0].strVal == "..":
                    # handle char ranges like '0'..'9' or
                    # variations like 'a'..'z' & 'A'..'Z'
                    var leftTk = tk[2][1]
                    var rightTk = tk[2][2]
                    if leftTk.kind == nnkCharLit and rightTk.kind == nnkCharLit:
                        let leftTkChar = char(leftTk.intVal)
                        let rightTkChar = char(rightTk.intVal)
                        if prefPromptTokens == true:
                            let keyword = $(leftTkChar & infixStr & rightTkChar)
                            echo "\n  Token:", indent(tk[1].strVal, 7), "\n  Keyword:", indent(keyword, 5)
                    else:
                        discard
                        # echo leftTk.kind
                        # echo rightTk.kind
            else:
                # Collect all char-based cases
                # echo tk[2].kind
                caseCharTokens.add((charToken: char(tk[2].intval), tokToken: tk[1].strVal))
                # caseCharTokens.add(char(tk[2].intVal))
                discard
        else: discard   # TODO raise error

    # add TK_EOF at the end
    tkIdent = newIdentNode(toUpperAscii(tkEOF.strVal))
    enumTokensNode.add(tkIdent)

    tkIdent = newIdentNode(toUpperAscii(tkIdentifier.strVal))
    enumTokensNode.add(tkIdent)

    # TokenKind enum
    result.add(
        newNimNode(nnkTypeSection).add(
            newNimNode(nnkTypeDef).add(
                newNimNode(nnkPostfix).add(
                    newIdentNode("*"),
                    newIdentNode(enum_token_ident.strVal)
                ),
                newEmptyNode(),
                enumTokensNode
            )
        )
    )
    
    # LexerException object
    # LexerException = object of CatchableError
    result.add(
        newNimNode(nnkTypeSection).add(
            newNimNode(nnkTypeDef).add(
                newNimNode(nnkPostfix).add(
                    newIdentNode("*"),
                    newIdentNode(lexer_exception_ident.strVal)
                ),
                newEmptyNode(),
                newNimNode(nnkObjectTy).add(
                    newEmptyNode(),
                    newNimNode(nnkOfInherit).add(newIdentNode("CatchableError")),
                    newEmptyNode()
                )
            )
        )
    )

    # Create TokenTuple
    # TokenTuple = tuple[kind: TokenKind, value: string, wsno, col, line: int]
    result.add(
        newNimNode(nnkTypeSection).add(
            newNimNode(nnkTypeDef).add(
                newNimNode(nnkPostfix).add(
                    newIdentNode("*"),
                    newIdentNode(token_tuple_ident.strval)
                ),
                newEmptyNode(),
                newNimNode(nnkTupleTy).add(
                    newNimNode(nnkIdentDefs).add(
                        newIdentNode("kind"),
                        newIdentNode(enum_token_ident.strVal),
                        newEmptyNode()
                    ),
                    newNimNode(nnkIdentDefs).add(
                        newIdentNode("value"),
                        newIdentNode("string"),
                        newEmptyNode()
                    ),
                    newNimNode(nnkIdentDefs).add(
                        newIdentNode("wsno"),
                        newIdentNode("col"),
                        newIdentNode("line"),
                        newIdentNode("int"),
                        newEmptyNode()
                    ),
                )
            )
        )
    )

    # Create Token = object
    var fields = @[
        (key: "kind", fType: enum_token_ident.strval),
        (key: "token", fType: "string"),
        (key: "error", fType: "string"),
        (key: "startPos", fType: "int"),
        (key: "wsno", fType: "int"),
    ]

    var objectFields = newNimNode(nnkRecList)
    for f in fields:
        objectFields.add(
            newNimNode(nnkIdentDefs).add(
                newIdentNode(f.key),
                newIdentNode(f.fType),
                newEmptyNode()
            )
        )

    result.add(
        newNimNode(nnkTypeSection).add(
            newNimNode(nnkTypeDef).add(
                newNimNode(nnkPostfix).add(
                    newIdentNode("*"),
                    newIdentNode(lexer_object_ident.strVal)
                ),
                newEmptyNode(),
                newNimNode(nnkObjectTy).add(
                    newEmptyNode(),
                    newNimNode(nnkOfInherit).add(newIdentNode("BaseLexer")),
                    objectFields
                )
            )
        )
    )

    result.add(
        nnkIncludeStmt.newTree(
            nnkInfix.newTree(
                newIdentNode("/"),
                newIdentNode("toktok"),
                newIdentNode("lexutils")
            )
        )
    )

    # Start creation of Case Statement, and add the first case
    # case lex.buf[lex.bufpos]:
    var mainCaseStatements = newNimNode(nnkCaseStmt)
    mainCaseStatements.add(
        nnkBracketExpr.newTree(
            nnkDotExpr.newTree(
                newIdentNode("lex"),
                newIdentNode("buf")
            ),
            nnkDotExpr.newTree(
                newIdentNode("lex"),
                newIdentNode("bufpos")
            )
        )
    )

    # of EndOfFile:
    #   lex.startPos = lex.getColNumber(lex.bufpos)
    #   lex.kind = TK_EOF
    mainCaseStatements.add(
        nnkOfBranch.newTree(
            newIdentNode("EndOfFile"),
            nnkStmtList.newTree(
                nnkAsgn.newTree(
                    nnkDotExpr.newTree(
                        newIdentNode("lex"),
                        newIdentNode("startPos")
                    ),
                    nnkCall.newTree(
                        nnkDotExpr.newTree(
                            newIdentNode("lex"),
                            newIdentNode("getColNumber")
                        ),
                        nnkDotExpr.newTree(
                            newIdentNode("lex"),
                            newIdentNode("bufpos")
                        )
                    )
                ),
                nnkAsgn.newTree(
                    nnkDotExpr.newTree(
                        newIdentNode("lex"),
                        newIdentNode("kind")
                    ),
                    newIdentNode("TK_EOF")
                )
            )
        )
    )

    # Define case statements for string-based identifiers
    # This case is triggered via handleIdent() template from lexutils,
    var strBasedCaseStatement = newNimNode(nnkCaseStmt)
    strBasedCaseStatement.add(
        newNimNode(nnkDotExpr).add(
            newIdentNode("lex"),
            newIdentNode("token")
        )
    )
    for caseStr in caseStrTokens:
        let tokTokenStr = toUpperAscii(tkPrefix.strVal & caseStr.tokToken)
        # echo tokTokenStr
        strBasedCaseStatement.add(
            newNimNode(nnkOfBranch).add(
                newLit(caseStr.strToken),
                newNimNode(nnkStmtList).add(newIdentNode(tokTokenStr))
            )
        )

    strBasedCaseStatement.add(
        newNimNode(nnkElse).add(
            newNimNode(nnkStmtList).add(newIdentNode("TK_IDENTIFIER"))
        )
    )

    # Create `generateIdentCase()` template and define
    # case for string-based tokens
    var identCaseTemplate = newNimNode(nnkTemplateDef)
    identCaseTemplate.add(
        newNimNode(nnkPostfix).add(
            newIdentNode("*"),
            newIdentNode("generateIdentCase")
        ),
        newEmptyNode(),
        newNimNode(nnkGenericParams).add(
            newNimNode(nnkIdentDefs).add(
                newIdentNode("L"),
                newIdentNode("Lexer"),
                newEmptyNode()
            )
        ),
        newNimNode(nnkFormalParams).add(
            newEmptyNode(),
            newNimNode(nnkIdentDefs).add(
                newIdentNode("lex"),
                newNimNode(nnkVarTy).add(
                    newIdentNode("L")
                ),
                newEmptyNode()
            )
        ),
        newEmptyNode(),
        newEmptyNode(),
        newNimNode(nnkStmtList).add(
            newNimNode(nnkAsgn).add(
                newNimNode(nnkDotExpr).add(
                    newIdentNode("lex"),
                    newIdentNode("kind")
                ),
                strBasedCaseStatement
            )
        )
    )

    # create template generateIdentCase*() =
    result.add(identCaseTemplate)

    # Push a-z-A-Z range to Main Case Statement
    # This case is handled by handleIdent
    mainCaseStatements.add(
        newNimNode(nnkOfBranch).add(
            newNimNode(nnkInfix).add(
                newIdentNode(".."),
                newLit('a'),
                newLit('z')
            ),
            newNimNode(nnkInfix).add(
                newIdentNode(".."),
                newLit('A'),
                newLit('Z')
            ),
            # newLit('_'),
            # newLit('-'),
            newNimNode(nnkStmtList).add(
                newNimNode(nnkCall).add(
                    newNimNode(nnkDotExpr).add(
                        newIdentNode("lex"),
                        newIdentNode("handleIdent")
                    )
                )
            )
        )
    )

    # Add to Main Case Statement char-based tokens
    for caseChar in caseCharTokens:
        let tokTokenStr = toUpperAscii(tkPrefix.strVal & caseChar.tokToken)
        # echo tokTokenStr
        mainCaseStatements.add(
            newNimNode(nnkOfBranch).add(
                newLit(caseChar.charToken),
                newNimNode(nnkCall).add(
                    newNimNode(nnkDotExpr).add(
                        newIdentNode("lex"),
                        newIdentNode("setToken")
                    ),
                    newIdentNode(tokTokenStr),
                    newLit(1)                           # char token offset in lex.bufpos
                )
            )
        )

    mainCaseStatements.add(
        newNimNode(nnkElse).add(
            nnkStmtList.newTree(
                nnkAsgn.newTree(
                    nnkDotExpr.newTree(
                        newIdentNode("lex"),
                        newIdentNode("kind")
                    ),
                    newIdentNode("TK_IDENTIFIER")
                )
            )
        )
    )

    # Create a public procedure that retrieves token one by one.
    # This proc should be used in the main while iteration inside your parser:
    # proc getToken*[T: Lexer](lex: var T): TokenTuple =
    result.add(
        nnkProcDef.newTree(
            nnkPostfix.newTree(
                newIdentNode("*"),
                newIdentNode("getToken")
            ),
            newEmptyNode(),
            nnkGenericParams.newTree(
                nnkIdentDefs.newTree(
                    newIdentNode("T"),
                    newIdentNode("Lexer"),
                    newEmptyNode()
                )
            ),
            nnkFormalParams.newTree(
                newIdentNode(token_tuple_ident.strVal),
                nnkIdentDefs.newTree(
                    newIdentNode("lex"),
                    nnkVarTy.newTree(
                        newIdentNode("T")
                    ),
                    newEmptyNode()
                )
            ),
            newEmptyNode(),
            newEmptyNode(),
            nnkStmtList.newTree(
                # lex.startPos = lex.getColNumber(lex.bufpos)
                nnkAsgn.newTree(
                    nnkDotExpr.newTree(
                        newIdentNode("lex"),
                        newIdentNode("kind")
                    ),
                    newIdentNode("TK_UNKNOWN")
                ),
                # setLen(lex.token, 0)
                nnkCall.newTree(
                    newIdentNode("setLen"),
                    nnkDotExpr.newTree(
                        newIdentNode("lex"),
                        newIdentNode("token")
                    ),
                    newLit(0)
                ),
                nnkCommand.newTree(
                    newIdentNode("skip"),
                    newIdentNode("lex")
                ),

                # Unpack collected case statements
                # for char, string and int-based tokens
                mainCaseStatements,
                
                nnkAsgn.newTree(
                    newIdentNode("result"),
                    nnkTupleConstr.newTree(
                        nnkExprColonExpr.newTree(
                            newIdentNode("kind"),
                            nnkDotExpr.newTree(
                                newIdentNode("lex"),
                                newIdentNode("kind")
                            )
                        ),
                        nnkExprColonExpr.newTree(
                            newIdentNode("value"),
                            nnkDotExpr.newTree(
                                newIdentNode("lex"),
                                newIdentNode("token")
                            )
                        ),
                        nnkExprColonExpr.newTree(
                            newIdentNode("wsno"),
                            nnkDotExpr.newTree(
                                newIdentNode("lex"),
                                newIdentNode("wsno")
                            )
                        ),
                        nnkExprColonExpr.newTree(
                            newIdentNode("col"),
                            nnkDotExpr.newTree(
                                newIdentNode("lex"),
                                newIdentNode("startPos")
                            )
                        ),
                        nnkExprColonExpr.newTree(
                            newIdentNode("line"),
                            nnkDotExpr.newTree(
                                newIdentNode("lex"),
                                newIdentNode("lineNumber")
                            )
                        )
                    )
                )
            )
        )
    )
