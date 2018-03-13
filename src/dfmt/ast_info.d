//          Copyright Brian Schott 2015.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dfmt.ast_info;

import dparse.lexer;
import dparse.ast;

enum BraceIndentInfoFlags
{
    tempIndent = 1 << 0,
}

struct BraceIndentInfo
{
    size_t startLocation;
    size_t endLocation;

    uint flags;

    uint beginIndentLevel;
}

/// AST information that is needed by the formatter.
struct ASTInformation
{
    /// Sorts the arrays so that binary search will work on them
    void cleanup()
    {
        import std.algorithm : sort;

        sort(doubleNewlineLocations);
        sort(spaceAfterLocations);
        sort(unaryLocations);
        sort(attributeDeclarationLines);
        sort(caseEndLocations);
        sort(structInitStartLocations);
        sort(structInitEndLocations);
        sort(funLitStartLocations);
        sort(funLitEndLocations);
        sort(conditionalWithElseLocations);
        sort(conditionalStatementLocations);
        sort(arrayStartLocations);
        sort(arrayEndLocations);
        sort(contractLocations);
        sort(constraintLocations);
        sort(constructorDestructorLocations);
        sort(staticConstructorDestructorLocations);
        sort(sharedStaticConstructorDestructorLocations);

        sort!((a,b) => a.endLocation < b.endLocation)
            (indentInfoSortedByEndLocation);
    }

    /// Locations of end braces for struct bodies
    size_t[] doubleNewlineLocations;

    /// Locations of tokens where a space is needed (such as the '*' in a type)
    size_t[] spaceAfterLocations;

    /// Locations of unary operators
    size_t[] unaryLocations;

    /// Lines containing attribute declarations
    size_t[] attributeDeclarationLines;

    /// Case statement colon locations
    size_t[] caseEndLocations;

    /// Opening braces of struct initializers
    size_t[] structInitStartLocations;

    /// Closing braces of struct initializers
    size_t[] structInitEndLocations;

    /// Opening braces of function literals
    size_t[] funLitStartLocations;

    /// Closing braces of function literals
    size_t[] funLitEndLocations;

    /// Conditional statements that have matching "else" statements
    size_t[] conditionalWithElseLocations;

    /// Conditional statement locations
    size_t[] conditionalStatementLocations;

    /// Locations of start locations of array initializers
    size_t[] arrayStartLocations;

    /// Locations of end locations of array initializers
    size_t[] arrayEndLocations;

    /// Locations of "in" and "out" tokens that begin contracts
    size_t[] contractLocations;

    /// Locations of template constraint "if" tokens
    size_t[] constraintLocations;

    /// Locations of constructor/destructor "shared" tokens ?
    size_t[] sharedStaticConstructorDestructorLocations;

    /// Locations of constructor/destructor "static" tokens ?
    size_t[] staticConstructorDestructorLocations;

    /// Locations of constructor/destructor "this" tokens ?
    size_t[] constructorDestructorLocations;

    BraceIndentInfo[] indentInfoSortedByEndLocation;
}

/// Collects information from the AST that is useful for the formatter
final class FormatVisitor : ASTVisitor
{
    alias visit = ASTVisitor.visit;

    /**
     * Params:
     *     astInformation = the AST information that will be filled in
     */
    this(ASTInformation* astInformation)
    {
        this.astInformation = astInformation;
    }

    override void visit(const ArrayInitializer arrayInitializer)
    {
        astInformation.arrayStartLocations ~= arrayInitializer.startLocation;
        astInformation.arrayEndLocations ~= arrayInitializer.endLocation;
        arrayInitializer.accept(this);
    }

    override void visit (const SharedStaticConstructor sharedStaticConstructor)
    {
        astInformation.sharedStaticConstructorDestructorLocations ~= sharedStaticConstructor.location;
        sharedStaticConstructor.accept(this);
    }

    override void visit (const SharedStaticDestructor sharedStaticDestructor)
    {
        astInformation.sharedStaticConstructorDestructorLocations ~= sharedStaticDestructor.location;
        sharedStaticDestructor.accept(this);
    }

    override void visit (const StaticConstructor staticConstructor)
    {
        astInformation.staticConstructorDestructorLocations ~= staticConstructor.location;
        staticConstructor.accept(this);
    }

    override void visit (const StaticDestructor staticDestructor)
    {
        astInformation.staticConstructorDestructorLocations ~= staticDestructor.location;
        staticDestructor.accept(this);
    }

    override void visit (const Constructor constructor)
    {
        astInformation.constructorDestructorLocations ~= constructor.location;
        constructor.accept(this);
    }

    override void visit (const Destructor destructor)
    {
        astInformation.constructorDestructorLocations ~= destructor.index;
        destructor.accept(this);
    }

    override void visit(const ConditionalDeclaration dec)
    {
        if (dec.hasElse)
        {
            auto condition = dec.compileCondition;
            if (condition.versionCondition !is null)
            {
                astInformation.conditionalWithElseLocations
                    ~= condition.versionCondition.versionIndex;
            }
            else if (condition.debugCondition !is null)
            {
                astInformation.conditionalWithElseLocations ~= condition.debugCondition.debugIndex;
            }
            // Skip "static if" because the formatting for normal "if" handles
            // it properly
        }
        dec.accept(this);
    }

    override void visit(const Constraint constraint)
    {
        astInformation.constraintLocations ~= constraint.location;
        constraint.accept(this);
    }

    override void visit(const ConditionalStatement statement)
    {
        auto condition = statement.compileCondition;
        if (condition.versionCondition !is null)
        {
            astInformation.conditionalStatementLocations ~= condition.versionCondition.versionIndex;
        }
        else if (condition.debugCondition !is null)
        {
            astInformation.conditionalStatementLocations ~= condition.debugCondition.debugIndex;
        }
        statement.accept(this);
    }

    override void visit(const FunctionLiteralExpression funcLit)
    {
        if (funcLit.functionBody !is null)
        {
            const bs = funcLit.functionBody.blockStatement;

            astInformation.funLitStartLocations ~= bs.startLocation;
            astInformation.funLitEndLocations ~= bs.endLocation;
            astInformation.indentInfoSortedByEndLocation ~=
                BraceIndentInfo(bs.startLocation, bs.endLocation);
        }
        funcLit.accept(this);
    }

    override void visit(const DefaultStatement defaultStatement)
    {
        astInformation.caseEndLocations ~= defaultStatement.colonLocation;
        defaultStatement.accept(this);
    }

    override void visit(const CaseStatement caseStatement)
    {
        astInformation.caseEndLocations ~= caseStatement.colonLocation;
        caseStatement.accept(this);
    }

    override void visit(const CaseRangeStatement caseRangeStatement)
    {
        astInformation.caseEndLocations ~= caseRangeStatement.colonLocation;
        caseRangeStatement.accept(this);
    }

    override void visit(const FunctionBody functionBody)
    {
        if (functionBody.blockStatement !is null)
            astInformation.doubleNewlineLocations ~= functionBody.blockStatement.endLocation;
        if (functionBody.bodyStatement !is null && functionBody.bodyStatement
                .blockStatement !is null)
            astInformation.doubleNewlineLocations
                ~= functionBody.bodyStatement.blockStatement.endLocation;
        functionBody.accept(this);
    }

    override void visit(const StructInitializer structInitializer)
    {
        astInformation.structInitStartLocations ~= structInitializer.startLocation;
        astInformation.structInitEndLocations ~= structInitializer.endLocation;
        astInformation.indentInfoSortedByEndLocation ~=
            BraceIndentInfo(structInitializer.startLocation, structInitializer.endLocation);

        structInitializer.accept(this);
    }

    override void visit(const EnumBody enumBody)
    {
        astInformation.doubleNewlineLocations ~= enumBody.endLocation;
        enumBody.accept(this);
    }

    override void visit(const Unittest unittest_)
    {
        astInformation.doubleNewlineLocations ~= unittest_.blockStatement.endLocation;
        unittest_.accept(this);
    }

    override void visit(const Invariant invariant_)
    {
        astInformation.doubleNewlineLocations ~= invariant_.blockStatement.endLocation;
        invariant_.accept(this);
    }

    override void visit(const StructBody structBody)
    {
        astInformation.doubleNewlineLocations ~= structBody.endLocation;
        structBody.accept(this);
    }

    override void visit(const TemplateDeclaration templateDeclaration)
    {
        astInformation.doubleNewlineLocations ~= templateDeclaration.endLocation;
        templateDeclaration.accept(this);
    }

    override void visit(const TypeSuffix typeSuffix)
    {
        if (typeSuffix.star.type != tok!"")
            astInformation.spaceAfterLocations ~= typeSuffix.star.index;
        typeSuffix.accept(this);
    }

    override void visit(const UnaryExpression unary)
    {
        if (unary.prefix.type == tok!"~" || unary.prefix.type == tok!"&"
                || unary.prefix.type == tok!"*"
                || unary.prefix.type == tok!"+" || unary.prefix.type == tok!"-")
        {
            astInformation.unaryLocations ~= unary.prefix.index;
        }
        unary.accept(this);
    }

    override void visit(const AttributeDeclaration attributeDeclaration)
    {
        astInformation.attributeDeclarationLines ~= attributeDeclaration.line;
        attributeDeclaration.accept(this);
    }

    override void visit(const InStatement inStatement)
    {
        astInformation.contractLocations ~= inStatement.inTokenLocation;
        inStatement.accept(this);
    }

    override void visit(const OutStatement outStatement)
    {
        astInformation.contractLocations ~= outStatement.outTokenLocation;
        outStatement.accept(this);
    }

private:
    ASTInformation* astInformation;
}
