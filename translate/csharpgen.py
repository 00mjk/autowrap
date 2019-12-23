import enum
import ir


class TopLevelTranslateIrVisitor(ir.IrVisitor):
    def __init__(self, gen):
        self.gen = gen
        self.non_function_nodes = []

    def visit_UnsupportedNode(self, node):
        self.non_function_nodes.append(node)

    def visit_Function(self, node):
        self.gen.writeln(f"[Microsoft.VisualStudio.TestTools.UnitTesting.TestMethod]")
        self.gen.default_ir_visitor.visit(node)


class DefaultTranslateIrVisitor(ir.IrVisitor):
    def __init__(self, gen):
        self.gen = gen

    def visit_UnsupportedNode(self, node):
        self.gen.writeln(f"// TODO: this node is not supported {node.ast_node}")

    def visit_Function(self, node):
        self.gen.writeln(f"public void {node.name}()")
        self.gen.open_block()
        # TODO: visit the function body to generate C# code
        # self.visit(node.body)

        self.gen.writeln("// TODO: generate function body")
        self.gen.close_block()


# a small helper function for generating C# code
class CSharpGenerator:
    def __init__(self, out_file):
        self.out_file = out_file
        self.tab_depth = 0
        self.default_ir_visitor = DefaultTranslateIrVisitor(self)

    def get_line_prefix(self):
        return self.tab_depth * 4 * " "

    def writeln(self, line):
        self.out_file.write(f"{self.get_line_prefix()}{line}\n")

    def open_block(self):
        self.writeln("{")
        self.tab_depth += 1

    def close_block(self):
        self.tab_depth -= 1
        self.writeln("}")

    def translate(self, module):
        # TODO: visit all the nodes to determine project/assembly references
        #       for now just hard-code them
        # NOTE: these assembly_references will change depending on the .NET version we are targeting
        assembly_references = [
            "System",
            "Microsoft.VisualStudio.QualityTools.UnitTestFramework, Version=9.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a, processorArchitecture=MSIL",
        ]

        self.writeln("// this file is autogenerated, do not modify by hand")

        # here we write the assembly_references in the source file for now as comments,
        # normally these are included in the project file
        for reference in assembly_references:
            self.writeln(f'// <Reference Include="{reference}" />')

        # no need to generate a namespace here
        # autowrap doesn't need to test .NET's namespace semantics

        # we use the fully-qualified names to avoid name-collisions with the symbols from the test
        self.writeln(f"[Microsoft.VisualStudio.TestTools.UnitTesting.TestClass]")
        self.writeln("public class TestMain")
        self.open_block()

        top_level_visitor = TopLevelTranslateIrVisitor(self)
        for node in module.nodes:
            top_level_visitor.visit(node)

        if len(top_level_visitor.non_function_nodes) > 0:
            self.writeln(f"[Microsoft.VisualStudio.TestTools.UnitTesting.TestInitialize]")
            self.writeln("public void __TestInit()")
            self.open_block()
            for node in top_level_visitor.non_function_nodes:
                self.default_ir_visitor.visit(node)
            self.close_block()

        self.close_block()


def translate(module, filename):
    with open(filename, "w") as file:
        CSharpGenerator(file).translate(module)
