# the template for the dot output file

dTemp = """/* created with ERDot < https://github.com/ehne/ERDot > */
digraph ERDiagram {
    graph [
        nodesep=0.2;
        rankdir="LR";
        concentrate=true;
        beautify=true;
        splines="spline";
        fontname="Helvetica";
        bgcolor="lightgray";
        pad="5,5",
        label="{{lbl}}",
        {{gs}}
    ];
    
    node [shape=shape, fontname="Helvetica", fontsize=12, fillcolor="white", style="filled", color="black", penwidth=1.0, margin="0.05,0.05"];
    edge [
        dir=both,
        fontsize=12,
        arrowsize=0.9,
        color="red",
        penwidth=1.0,
        labelangle=32,
        labeldistance=1.8,
        fontname="Helvetica"
    ];

    % for i in tables:
    "{{i}}" [shape=none, margin=0, label=<
        <table border="0" cellborder="0" cellspacing="0" >
        <tr><td colspan="2"><i>{{i}}</i></td></tr>
    % for k in tables[i]:
        <tr>
            <td port="{{k.replace('+', '').replace('*', '').replace('!', '')}}" align="left" cellpadding="3">
            % if "+" in k or "*" in k:
<b>{{k.replace("+","FK ").replace("*","PK ")}}</b>
            % elif "!" in k:
<u><i>{{k.replace("!","")}}</i></u>
            % else:
{{k}}
            % end
            </td>        
            <td align="right" cellpadding="3">{{tables[i][k]}}</td>
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
