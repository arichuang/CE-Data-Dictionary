
function ExecSQL {
    param (
        [Parameter(Mandatory)]
        [string] $Query,
        [Parameter(Mandatory=$false)]
        [string] $database = "Phase25Test"
    )

    <# Envirnoment Variables #>
    $Server = "10.210.3.1"              #Test Server
    $DB = $database                     #Test database name
    $u = "XX"							#Fill in username
    $p = "XXXX"					#Fill in password

    $Timeout = 30                     #60 minutes

    Invoke-Sqlcmd `
        -ServerInstance $Server `
        -Database $DB `
        -Username $u `
        -Password $p `
        -TrustServerCertificate `
        -QueryTimeout $Timeout `
        -Query $Query `
        | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors
}

function TableList {
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Customer','Equipment & Tanks','Transactions','Accounting','Inventory','Pricing')]
        [string] $ReportType
    )

    $tables = ExecSQL "
    --drop table if exists #sections

    create table #sections(DataGroup varchar(300),TableReference varchar(300))
    
    insert into #sections (datagroup,tablereference) select 'Customer','bEntity'
    insert into #sections (datagroup,tablereference) select 'Equipment & Tanks','bEquipment'
    insert into #sections (datagroup,tablereference) select 'Transactions','bDocument'
    insert into #sections (datagroup,tablereference) select 'Accounting','bDocumentDistribution'
    insert into #sections (datagroup,tablereference) select 'Inventory','bItem'
    insert into #sections (datagroup,tablereference) select 'Pricing','bPriceCode'
    
    
    --drop table if exists #tables
    select distinct * into #tables from (
    
    /*Foreign Keys for table*/
    SELECT  --obj.name AS FK_NAME,
        --sch.name AS [schema_name],
        tab1.name AS tableName--[table]
        ,tab2.name AS [referenced_table]
        ,col1.name AS [column]
        ,1 ValidFK
        --col2.name AS [referenced_column]
        FROM sys.foreign_key_columns fkc
        INNER JOIN sys.objects obj
            ON obj.object_id = fkc.constraint_object_id
        INNER JOIN sys.tables tab1
            ON tab1.object_id = fkc.parent_object_id
        INNER JOIN sys.schemas sch
            ON tab1.schema_id = sch.schema_id
        INNER JOIN sys.columns col1
            ON col1.column_id = parent_column_id AND col1.object_id = tab1.object_id
        INNER JOIN sys.tables tab2
            ON tab2.object_id = fkc.referenced_object_id
        INNER JOIN sys.columns col2
            ON col2.column_id = referenced_column_id AND col2.object_id = tab2.object_id
        inner join #sections s on s.TableReference=tab1.name
    
    union
    
    /*Foreign Key in other Tables*/
    SELECT  --obj.name AS tableName,
        --sch.name AS [schema_name],
        tab2.name AS  tableName
        ,tab1.name AS [referenced_table]
        ,col2.name AS [column]
        ,1 ValidFK
        --,col2.name AS [referenced_column]
        FROM sys.foreign_key_columns fkc
        INNER JOIN sys.objects obj
            ON obj.object_id = fkc.constraint_object_id
        INNER JOIN sys.tables tab1
            ON tab1.object_id = fkc.parent_object_id
        INNER JOIN sys.schemas sch
            ON tab1.schema_id = sch.schema_id
        INNER JOIN sys.columns col1
            ON col1.column_id = parent_column_id AND col1.object_id = tab1.object_id
        INNER JOIN sys.tables tab2
            ON tab2.object_id = fkc.referenced_object_id
        INNER JOIN sys.columns col2
            ON col2.column_id = referenced_column_id AND col2.object_id = tab2.object_id
        inner join #sections s on s.TableReference=tab2.name
    
    union
    
    /*Fake Foreigns in table*/
    SELECT t.name--, c.name
    ,case when right(c.name,2)='ID' then SUBSTRING(c.name,1,len(c.name)-2) else c.name end referencedtable 
    ,c.name
    ,0
        FROM sys.columns c
        INNER JOIN sys.tables t
            ON t.object_id = c.object_id
        INNER JOIN sys.indexes i
            ON i.object_id = t.object_id
        LEFT JOIN sys.foreign_key_columns fkc_Parent
            ON fkc_Parent.parent_column_id = c.column_id
            AND fkc_Parent.parent_object_id = c.object_id
        LEFT JOIN sys.foreign_key_columns fkc_Referenced
            ON fkc_Referenced.Referenced_column_id = c.column_id
            AND fkc_Referenced.Referenced_object_id = c.object_id
        LEFT JOIN sys.index_columns ic
            ON ic.index_id = i.index_id
            AND ic.object_id = t.object_id
            AND ic.column_id = c.column_id
        inner join #sections s on s.TableReference= t.name
            
        WHERE fkc_Referenced.constraint_object_id IS NULL
            AND fkc_Parent.constraint_column_id IS NULL
            AND ic.index_column_id IS NULL
            AND c.name LIKE '%id'
            AND i.is_primary_key = 1
            and c.name<>s.TableReference+'ID'
            --and t.name ='bEntity'
    
    union 
    
    /*Fake Foreigns Key in other tables*/
        SELECT s.tablereference,t.name referencedtable,c.name  ,0
        FROM sys.columns c
        INNER JOIN sys.tables t
            ON t.object_id = c.object_id
        INNER JOIN sys.indexes i
            ON i.object_id = t.object_id
        LEFT JOIN sys.foreign_key_columns fkc_Parent
            ON fkc_Parent.parent_column_id = c.column_id
            AND fkc_Parent.parent_object_id = c.object_id
        LEFT JOIN sys.foreign_key_columns fkc_Referenced
            ON fkc_Referenced.Referenced_column_id = c.column_id
            AND fkc_Referenced.Referenced_object_id = c.object_id
        LEFT JOIN sys.index_columns ic
            ON ic.index_id = i.index_id
            AND ic.object_id = t.object_id
            AND ic.column_id = c.column_id
        inner join #sections s on s.TableReference+'ID'= c.name
        WHERE fkc_Referenced.constraint_object_id IS NULL
            AND fkc_Parent.constraint_column_id IS NULL
            AND ic.index_column_id IS NULL
            --AND c.name = 'bEntityid'
            AND i.is_primary_key = 1
    ) a
        
    /*Have 'ID' column however not an actual table; ie bEquipment.OriginalEquipmentID, bDocument.Void*/
    delete t
    --select * 
    from #tables t
    left JOIN sys.tables tb on t.referenced_table=tb.name
    where tb.object_id is null

    
    /*The Same table is referenced in the Transaction and other groups but the table name has 'bDocument' in it, so lets put that in the 'Transaction' group*/
    delete i
    --select * 
    from #tables t
    join #tables i on i.referenced_table=t.referenced_table and i.tableName <>'bDocument'
    where t.tableName='bDocument'
    and (t.referenced_table like '%bdocument%' or  t.referenced_table like '%transaction%' or  t.referenced_table like '%invoice%'  or  t.referenced_table like '%sale%' 
        or  t.referenced_table like '%cash%' )
    
    
    /*The Same table is referenced in the Account and other groups but the table name has 'bEntity' in it, so lets put that in the 'Accouunt' group*/
    delete i
    --select * 
    from #tables t
    join #tables i on i.referenced_table=t.referenced_table and i.tableName <>'bEntity'
    where t.tableName='bEntity'
    and (t.referenced_table like '%bentity%' )

    /*Remove CargasQuery / QueryTemp tables */
    delete t
    --select * 
    from #tables t
    where t.referenced_table like 'CargasQuery%' or t.referenced_table like 'QueryTemp%'

    select t.tableName, referenced_table, [column] as 'col'
    From #tables t
    join #sections s ON t.tableName = s.TableReference
	where s.DataGroup = '$($ReportType)'

    union
	select TableReference, TableReference, ''
	From #sections
	where DataGroup = '$($ReportType)'

    "

    return $tables
}
    
function GetTableDefinition {
    param ( 
        [Parameter(Mandatory)]
        [string] $tblname 
    )

    ExecSQL " 
        SELECT 
            [ColumnName] = CAST(clmns.name AS VARCHAR(35)),
            [DataType] = ltrim(rtrim(udt.name)),
            [Length] = CAST(CAST(
                CASE 
                    WHEN typ.name IN (N'nchar', N'nvarchar') AND clmns.max_length <> -1 THEN clmns.max_length/2
                    ELSE clmns.max_length 
                END AS INT
            ) AS VARCHAR(20)),
            [IsPrimaryKey] = CAST(ISNULL(idxcol.index_column_id, 0)AS VARCHAR(20)),
            [IsForeignKey] = CAST((SELECT TOP 1 1
                    FROM sys.foreign_key_columns AS fkclmn
                    WHERE fkclmn.parent_column_id = clmns.column_id
                    AND fkclmn.parent_object_id = clmns.object_id
                    ) AS VARCHAR(20)),
            [ForeignTable] = CAST((SELECT TOP 1 OBJECT_NAME(fkclmn.referenced_object_id)
                    FROM sys.foreign_key_columns AS fkclmn
                    WHERE fkclmn.parent_column_id = clmns.column_id
                    AND fkclmn.parent_object_id = clmns.object_id
                    ) AS VARCHAR(20))
        FROM sys.tables AS tbl
            INNER JOIN sys.all_columns AS clmns				ON clmns.object_id=tbl.object_id
            LEFT OUTER JOIN sys.indexes AS idx				ON idx.object_id = clmns.object_id AND 1 =idx.is_primary_key
            LEFT OUTER JOIN sys.index_columns AS idxcol		ON idxcol.index_id = idx.index_id AND idxcol.column_id = clmns.column_id AND idxcol.object_id = clmns.object_id AND 0 = idxcol.is_included_column
            LEFT OUTER JOIN sys.types AS udt				ON udt.user_type_id = clmns.user_type_id
            LEFT OUTER JOIN sys.types AS typ				ON typ.user_type_id = clmns.system_type_id AND typ.user_type_id = typ.system_type_id
            LEFT JOIN sys.default_constraints AS cnstr		ON cnstr.object_id=clmns.default_object_id
            LEFT OUTER JOIN sys.extended_properties exprop	ON exprop.major_id = clmns.object_id AND exprop.minor_id = clmns.column_id AND exprop.name = 'MS_Description'
        WHERE ( tbl.name = '$tblname' )
        ORDER BY clmns.column_id ASC
    "
}

function FormatTable {
    param (
        [Parameter(Mandatory)]
        [string] $pk,
        [string] $fk,
        [string] $ftable,
        [string] $columnname,
        [string] $datatype,
        [string] $length,
        [string] $lastItem
    )

    if ($pk -eq 1) {
        $col = "*$columnname"
    } elseif ($fk -eq 1) {
         $col = "+$columnname"
    } elseif ($columnname -match "ID$" -and $datatype -eq "int") {
        $col = "!$columnname"
    } else {
        $col = $columnname
    }

    # If Length is -1 for types like varchar/char/nvarchar then is a max length
    if ( $datatype -like "*char" -and $length -eq -1) {
        $length = "max"
    }

    # Add Length to DataType if type like varchar/char/nvarchar
    if ( $datatype -like "*char" ) {
        $datatype += "($length)"
    }

    # Concatenate ColumnName and DataType
    if ($columnname -eq $lastItem) {
        # If this is the last item in the list, don't add a comma at the end
        $concatenatedString = '"{0}":"{1}"' -f $col, $datatype
    } else {
        $concatenatedString = '"{0}":"{1}",' -f $col, $datatype
    }
    return $concatenatedString
}

function CardinalValues {
    param (
        [Parameter(Mandatory)]
        [string] $pkTable,
        [string] $fkTable,
        [string] $joinOnColumn
    )

    # if ($fk -eq 1) {
        # If this is the last item in the list, don't add a comma at the end
        # if ($lastItem -ne $null -and $columnname -eq $lastItem) {
        #     $concatenatedString = '"{0}:{1} *--1 {2}:{3}"' -f $tbl, $columnname, $ftable, $columnname
        # } else {
            $concatenatedString = '"{0}:{1} *--1 {2}:{3}",' -f $pkTable, $joinOnColumn, $fkTable, $joinOnColumn
        # }
    # }
    return $concatenatedString
}

function main {
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Customer','Equipment & Tanks','Transactions','Accounting','Inventory','Pricing')]
        [string] $reportType
    )

    $getTables = TableList $reportType
    
    $listB = [System.Collections.Generic.List[string]]::new()

    Foreach ($tbl in $getTables) {

        #Built out Table definition
        $listA = [System.Collections.Generic.List[string]]::new()
        $tblValue = ''

        $fields = GetTableDefinition $tbl.referenced_table

        Foreach ($field in $fields) {
            $pk = $field.IsPrimaryKey
            $fk = $field.IsForeignKey
            $ftable = $field.ForeignTable
            $columnname = $field.ColumnName
            $datatype = $field.DataType
            $length = $field.Length

            #build table data
            $tblValue = FormatTable $pk $fk $ftable $columnname $datatype $length $fields[-1].ColumnName
            # Add the concatenated string to the output array
            $listA.Add($tblValue)
        }

        #Table Data
        $tablesData.AppendLine("`"$($tbl.referenced_table)`": {")
        $tablesData.AppendLine(($listA -join "`n`t").Insert(0, "`t"))
        #If this is the last table in the list, don't add a comma at the end
        if ($tbl.referenced_table -eq $getTables.referenced_table[-1]) {
            $tablesData.AppendLine("}")
        }
        else {
            $tablesData.AppendLine("},")
        }

        # Built out cardinality
        if ($tbl.col -ne '') {
            # Write-Output $tbl.tableName $tbl.referenced_table $tbl.col
            $cardinalValue = cardinalValues $tbl.tableName $tbl.referenced_table $tbl.col
            $listB.Add($cardinalValue)
        }
    }
    $relationshipString += $listB -join "`n`t`t"
    $relationshipString = $relationshipString -replace ",$"
    $relationdata.AppendLine($relationshipString.Insert(0, "`t`t"))


    #     foreach ($field in $fields) {
    #         $cardinalValue = ''

    #         $pk = $field.IsPrimaryKey
    #         $fk = $field.IsForeignKey
    #         $ftable = $field.ForeignTable
    #         $columnname = $field.ColumnName
    #         $datatype = $field.DataType
    #         $length = $field.Length

    #         Write-Host $pk $fk $ftable $columnname $datatype $length $fields[-1].ColumnName
    #         #Write-Host $fields[-1].ColumnName

    #         #build table data
    #         $tblValue = tblValues $pk $fk $ftable $columnname $datatype $length $fields[-1].ColumnName
    #         # Add the concatenated string to the output array
    #         # Write-Host $tblValue
    #         $listA.Add($tblValue)

    #         #build relationship data
    #         #Write-Host $tbl $fk $ftable $columnname $lastFkColumnName
    #         #$cardinalValue = cardinalValues $tbl $fk $ftable $columnname $lastFkColumnName
    #         # # Add the concatenated string to the output array
    #         #if ( $null -ne $cardinalValue ) {
    #         #    $listB.Add($cardinalValue)
    #         #}
    #     }

    #     #Table Data
    #     $tablesdata.AppendLine("`"$tbl`": {")
    #     $tablesdata.AppendLine(($listA -join "`n`t").Insert(0, "`t"))
    #     #If this is the last table in the list, don't add a comma at the end
    #     if ($tbl -eq  $gettables.Table_name[-1]) {
    #         $tablesdata.AppendLine("}")
    #     }
    #     else {
    #         $tablesdata.AppendLine("},")
    #     }

    #     # #Write-Host $listB
    #     #$relationshipString += $listB -join "`n`t`t"
    # }

    #Write-Host $relationshipString
    
    # $relationshipString = $relationshipString -replace ",$"
    # $relationdata.AppendLine($relationshipString.Insert(0, "`t`t"))    
}

    $tablesData = [System.Text.StringBuilder]::new()
    $relationdata = [System.Text.StringBuilder]::new()

    # Report Type: 'Customer','Equipment & Tanks','Transactions','Accounting','Inventory','Pricing'
    main -ReportType 'Equipment & Tanks'

    # Ouptput the final JSON
    $json_template = @"
{
    `"tables`": {
        $tablesdata
    },
    "relations":[
$relationdata
    ],
    "rankAdjustments":"",
    "label":""
}
"@

    $filename = "EquipmentTanks.erd.json"
    Set-Location "C:\Users\ahuang\OneDrive - Cargas Systems\Scripting\DataDictionary\ERD\"

    #$TablesData
    #Write-Host $json_template
    #output everything
    #Write-host $json_template | Out-File -FilePath "C:\Users\ahuang\OneDrive - Cargas Systems\Scripting\DataDictionary\ERD\output.erd.json"
    Write-Output $json_template | Out-File -FilePath $filename

    #Takes the .erd.json and converts it to .dot file
    Invoke-Expression "erdot $filename"