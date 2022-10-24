import SwiftSyntax

public struct RedundantTypeAnnotationRule: OptInRule, SwiftSyntaxCorrectableRule, ConfigurationProviderRule {
    public var configuration = SeverityConfiguration(.warning)

    public static let description = RuleDescription(
        identifier: "redundant_type_annotation",
        name: "Redundant Type Annotation",
        description: "Variables should not have redundant type annotation",
        kind: .idiomatic,
        nonTriggeringExamples: [
            Example("var url = URL()"),
            Example("var url: CustomStringConvertible = URL()"),
            Example("@IBInspectable var color: UIColor = UIColor.white"),
            Example("""
            enum Direction {
                case up
                case down
            }

            var direction: Direction = .up
            """),
            Example("""
            enum Direction {
                case up
                case down
            }

            var direction = Direction.up
            """)
        ],
        triggeringExamples: [
            Example("var url↓:URL=URL()"),
            Example("var url↓:URL = URL(string: \"\")"),
            Example("var url↓: URL = URL()"),
            Example("let url↓: URL = URL()"),
            Example("lazy var url↓: URL = URL()"),
            Example("let alphanumerics↓: CharacterSet = CharacterSet.alphanumerics"),
            Example("""
            class ViewController: UIViewController {
              func someMethod() {
                let myVar↓: Int = Int(5)
              }
            }
            """),
            Example("var isEnabled↓: Bool = true"),
            Example("""
            enum Direction {
                case up
                case down
            }

            var direction↓: Direction = Direction.up
            """),
            Example("let values↓: [Int] = [Int]()"),
            Example(#"static let version↓: AnnouncementStore.Attribute = AnnouncementStore.Attribute("Version")"#)
        ],
        corrections: [
            Example("var url↓: URL = URL()"): Example("var url = URL()"),
            Example("let url↓: URL = URL()"): Example("let url = URL()"),
            Example("let alphanumerics↓: CharacterSet = CharacterSet.alphanumerics"):
                Example("let alphanumerics = CharacterSet.alphanumerics"),
            Example("""
            class ViewController: UIViewController {
              func someMethod() {
                let myVar↓: Int = Int(5)
              }
            }
            """):
            Example("""
            class ViewController: UIViewController {
              func someMethod() {
                let myVar = Int(5)
              }
            }
            """),
            Example("let values↓: [Int] = [Int]()"): Example("let values = [Int]()"),
            Example(#"static let version↓: AnnouncementStore.Attribute = AnnouncementStore.Attribute("Version")"#):
                Example(#"static let version = AnnouncementStore.Attribute("Version")"#)
        ]
    )

    public init() {}

    public func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor {
        Visitor(viewMode: .sourceAccurate)
    }

    public func makeRewriter(file: SwiftLintFile) -> ViolationsSyntaxRewriter? {
        Rewriter(
            locationConverter: file.locationConverter,
            disabledRegions: disabledRegions(file: file)
        )
    }
}

private extension RedundantTypeAnnotationRule {
    final class Visitor: ViolationsSyntaxVisitor {
        override func visitPost(_ node: VariableDeclSyntax) {
            guard !node.isIBInspectable else {
                return
            }

            for binding in node.bindings {
                guard let typeAnnotation = binding.typeAnnotation,
                      binding.hasViolation else {
                    continue
                }

                violations.append(typeAnnotation.colon.positionAfterSkippingLeadingTrivia)
            }
        }
    }

    private final class Rewriter: SyntaxRewriter, ViolationsSyntaxRewriter {
        private(set) var correctionPositions: [AbsolutePosition] = []
        let locationConverter: SourceLocationConverter
        let disabledRegions: [SourceRange]

        init(locationConverter: SourceLocationConverter, disabledRegions: [SourceRange]) {
            self.locationConverter = locationConverter
            self.disabledRegions = disabledRegions
        }

        override func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
            guard !node.isIBInspectable else {
                return super.visit(node)
            }

            var modifiedBindings: [PatternBindingSyntax] = []
            var hasViolation = false

            for binding in node.bindings {
                guard let typeAnnotation = binding.typeAnnotation,
                      !typeAnnotation.isContainedIn(regions: disabledRegions, locationConverter: locationConverter),
                      binding.hasViolation else {
                    modifiedBindings.append(binding)
                    continue
                }

                correctionPositions.append(typeAnnotation.colon.positionAfterSkippingLeadingTrivia)

                let updatedInitializer = binding.initializer?.withLeadingTrivia(typeAnnotation.trailingTrivia ?? .space)
                modifiedBindings.append(
                    binding
                        .withTypeAnnotation(nil)
                        .withInitializer(updatedInitializer)
                )
                hasViolation = true
            }

            guard hasViolation else {
                return super.visit(node)
            }

            return super.visit(node.withBindings(PatternBindingListSyntax(modifiedBindings)))
        }
    }
}

private extension PatternBindingSyntax {
    var hasViolation: Bool {
        guard let typeAnnotation = typeAnnotation,
              let initializer = initializer?.value else {
            return false
        }

        if let function = initializer.as(FunctionCallExprSyntax.self) {
            return typeAnnotation.type.withoutTrivia().description ==
                function.calledExpression.withoutTrivia().description
        } else if let baseExpr = initializer.as(MemberAccessExprSyntax.self)?.base {
            return typeAnnotation.type.withoutTrivia().description == baseExpr.withoutTrivia().description
        } else if typeAnnotation.type.as(SimpleTypeIdentifierSyntax.self)?.name.text == "Bool" {
            return initializer.is(BooleanLiteralExprSyntax.self)
        }

        return false
    }
}

private extension VariableDeclSyntax {
    var isIBInspectable: Bool {
        attributes?.contains { attr in
            attr.as(AttributeSyntax.self)?.attributeName.text == "IBInspectable"
        } ?? false
    }
}
