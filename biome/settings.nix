# The Biome settings devkit shares. `base` is merged into every
# repository that enables Biome; `linter` is the `linter` section, merged
# in behind `devkit.biome.linter.enable`.
{
  base = {
    assist = {
      actions = {
        source = {
          organizeImports = {
            level = "on";
            options = {
              groups = [
                [
                  ":BUN:"
                  ":NODE:"
                ]
                ":BLANK_LINE:"
                ":PACKAGE:"
                ":BLANK_LINE:"
                "#~/**/*"
                ":BLANK_LINE:"
                "#@/**/*"
                ":BLANK_LINE:"
                [
                  "#$/**/*"
                  "#$$/**/*"
                  "#%/**/*"
                ]
              ];
            };
          };
        };
      };
    };
    formatter = {
      indentStyle = "space";
      lineWidth = 120;
    };
    javascript = {
      formatter = {
        quoteStyle = "single";
      };
    };
  };
  linter = {
    enabled = true;
    rules = {
      recommended = true;
      complexity = {
        noUselessFragments = {
          level = "warn";
        };
        noStaticOnlyClass = {
          level = "warn";
        };
        noUselessCatch = {
          level = "warn";
        };
        noBannedTypes = {
          level = "warn";
        };
        noForEach = {
          level = "off";
        };
        noExcessiveCognitiveComplexity = {
          level = "warn";
        };
        useSimplifiedLogicExpression = {
          level = "off";
        };
        noUselessTernary = {
          level = "error";
        };
        noArguments = {
          level = "error";
        };
        noCommaOperator = {
          level = "warn";
        };
      };
      performance = {
        noAccumulatingSpread = {
          level = "warn";
        };
      };
      correctness = {
        useUniqueElementIds = {
          level = "warn";
        };
        noNestedComponentDefinitions = {
          level = "warn";
        };
        noSelfAssign = {
          level = "warn";
        };
        noEmptyPattern = {
          level = "warn";
        };
        noUnsafeOptionalChaining = {
          level = "warn";
        };
        noInvalidUseBeforeDeclaration = {
          level = "warn";
        };
        useExhaustiveDependencies = {
          level = "warn";
        };
        noConstantCondition = {
          level = "warn";
        };
        noUnusedImports = {
          level = "error";
          fix = "safe";
        };
        noUnusedVariables = {
          level = "warn";
        };
        useHookAtTopLevel = {
          level = "error";
        };
        useJsxKeyInIterable = {
          level = "off";
        };
      };
      style = {
        useConsistentObjectDefinitions = {
          level = "error";
        };
        useDefaultParameterLast = {
          level = "off";
        };
        useConst = {
          level = "warn";
        };
        noParameterAssign = {
          level = "warn";
        };
        noNonNullAssertion = {
          level = "off";
        };
        noImplicitBoolean = {
          level = "off";
        };
        noNegationElse = {
          level = "error";
        };
        useBlockStatements = {
          level = "error";
        };
        useFilenamingConvention = {
          level = "error";
          options = {
            filenameCases = [
              "kebab-case"
            ];
          };
        };
        noRestrictedImports = {
          level = "error";
          options = {
            paths = {
              "node:assert" = "Not permitted, see penalty at https://github.com/nodejs/node/issues/52677";
              "assert" = "Not permitted, see penalty at https://github.com/nodejs/node/issues/52677";
            };
          };
        };
      };
      suspicious = {
        noTsIgnore = {
          level = "off";
        };
        noControlCharactersInRegex = {
          level = "warn";
        };
        noDuplicateCase = {
          level = "warn";
        };
        useDefaultSwitchClauseLast = {
          level = "warn";
        };
        noPrototypeBuiltins = {
          level = "warn";
        };
        noFallthroughSwitchClause = {
          level = "warn";
        };
        noRedeclare = {
          level = "warn";
        };
        noShadowRestrictedNames = {
          level = "warn";
        };
        noImplicitAnyLet = {
          level = "warn";
        };
        noAssignInExpressions = {
          level = "warn";
        };
        noConfusingVoidType = {
          level = "off";
        };
        noArrayIndexKey = {
          level = "warn";
        };
        noExplicitAny = {
          level = "warn";
        };
        noSkippedTests = {
          level = "off";
        };
        noFocusedTests = {
          level = "error";
        };
        noConsole = {
          level = "error";
          options = {
            allow = [
              "assert"
              "debug"
              "error"
              "info"
              "time"
              "timeEnd"
              "trace"
              "warn"
            ];
          };
        };
      };
      a11y = {
        noStaticElementInteractions = {
          level = "warn";
        };
        useIframeTitle = {
          level = "warn";
        };
        useButtonType = {
          level = "warn";
        };
        useHtmlLang = {
          level = "warn";
        };
        useKeyWithClickEvents = {
          level = "warn";
        };
        useAltText = {
          level = "warn";
        };
        noSvgWithoutTitle = {
          level = "warn";
        };
      };
      security = {
        noDangerouslySetInnerHtml = {
          level = "warn";
        };
      };
    };
  };
}
