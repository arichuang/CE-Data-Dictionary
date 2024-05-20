# the template for the dot output file

dTemp = """/* created with ERDot < https://github.com/ehne/ERDot > */
digraph ERDiagram {
ranksep=.25;

node [shape=plaintext, fontsize=48];
/* the tiers */
0 -> 1 -> 2 -> 3 -> 4;

node [shape=box, fontsize=14, style="rounded"];
/* the tables */

    % for i in tables:
    "{{i}}" [label=<
        <table border="0" cellborder="0" cellspacing="0">
        <tr><td colspan="2"><i>{{i}}</i></td></tr>
    % for k in tables[i]:
        <tr>
            <td port="{{k.replace('+', '').replace('*', '').replace('!', '')}}" align="left" cellpadding="3">
            % if "+" in k or "*" in k:
<b>{{k.replace("+","FK ").replace("*","PK ")}}</b></td>
            % elif "!" in k:
<u><i>{{k.replace("!","")}}</i></u></td>
            % else:
{{k}}</td>
            % end
            <td port="{{k.replace('+', '').replace('*', '').replace('!', '')}}" align="right" cellpadding="3">{{tables[i][k]}}</td>
        </tr>
    % end
    </table>>];
    % end

    % for i in relations:
    % q = i.split(" ")
    
    % k = q[1].split("--")
    % LeftCardinality = k[0]
    % RightCardinality = k[1]
    % q1lhs = q[0].split(":")[0]
    % q1rhs = q[0].split(":")[1]
    % q2lhs = q[2].split(":")[0]
    % q2rhs = q[2].split(":")[1]
    "{{q1lhs}}":"{{q1rhs}}"->"{{q2lhs}}":"{{q2rhs}}" [
    % if RightCardinality == "*":
        arrowhead=normal,
    % elif RightCardinality == "+":
        arrowhead=normal,
    % else:
        arrowhead=normal,
    % end
    % if LeftCardinality =="*":
        arrowtail=normal,
    % elif LeftCardinality == "+":
        arrowtail=normal,
    % else:
        arrowtail=normal,
    % end
    ];
    % end

    {{ra}}

}
"""
