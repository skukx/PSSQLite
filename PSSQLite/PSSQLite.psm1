Add-Type -Path "<PATH TO>\bin\System.Data.SQLite.dll"

<#
    .Synopsis
        Obtain a connection to SQLite database

    .Description
        Obtains a connection object to a specified database or creates a
        database if none exists. The database must reside in
        C:\inetpub\wwwroot\App_Data\

    .Parameter Database
        Name of database to connect to (include file extension)

    .Parameter New
        Specifies that this is a new database that needs to be
        created before connecting.

    .Example
        Get-SQLiteConnection -Database 'mydb.sqlite'

        # returns a connection to database mydb.sqlite

    .Example
        Get-SQLiteConnection -Database 'mynewdb.sqlite' -New

        # Creates the database mynewdb.sqlite and returns a connection
        # to it.
#>
function Get-SQLiteConnection {
    param (
        [Parameter(Mandatory=$True)]
        [String]
        $Database,

        [Parameter()]
        [Switch]
        $New
    )

    $createNew = $New.IsPresent
    if ( $createNew ) {
        [System.Data.SQLite.SQLiteConnection]::CreateFile($Database)
    }

    $connectionString = "Data Source=$WEB_ROOT\App_Data\$Database;foreign keys=true;"
    [System.Data.SQLite.SQLiteConnection]$connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)

    return $connection
}

<#
    .Synopsis
        Executes a non query (Insert, Delete, create, alter, etc)

    .Description
        Executes a non query and returns the number of rows
        affected

    .Parameter Connection
        The connection handle to the database obtained from
        Get-SQLiteConnection

    .Parameter Query
        The sql query to run "DELETE FROM table WHERE id=0"

    .Parameter Parameters
        A hashtable of values to bind. The key will be the parameter
        name and the value is the value to bind. @{'@param1' = 'myValue'}.
        This prevents sql injection.

    .Example
        Start-ExecuteNonQuery -Connection $connection -Query "INSERT INTO table (id, name) VALUES (1, 'george')"

        Executes an Insert without any bound parameters. 

    .Example
        Start-ExecuteNonQuery -Connection $connection -Query "INSERT INTO table (id, name) VALUES (@id, @name)" -Parameters @{ "@id"=1; "@name"="george" }

        Executes an Insert with bound parameters.
#>
function Invoke-SQLiteExecuteNonQuery {
    param (
        [Parameter(Mandatory=$True)]
        [System.Data.SQLite.SQLiteConnection]
        $Connection,

        [Parameter(Mandatory=$True)]
        [String]
        $Query,

        [Parameter()]
        [Hashtable]
        $Parameters
    )

    if ( $Connection.State -eq "Closed" ) {
        $Connection.Open()
    }

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Query
    foreach ( $key in $Parameters.Keys ) {
        $param = $cmd.CreateParameter()
        $param.ParameterName = $key
        $param.Value = $Parameters[$key]

        $Null = $cmd.Parameters.Add($param)
    }

    $result = $cmd.ExecuteNonQuery()
    $Connection.Close()

    $result
}

<#
    .Synopsis
        Executes a query

    .Description
        Executes a query and returns the rows found as an array
        of PSObjects

    .Parameter Connection
        The connection handle to the database obtained from
        Get-SQLiteConnection

    .Parameter Query
        The sql query to run "SELECT * FROM table"

    .Parameter Parameters
        A hashtable of values to bind. The key will be the parameter
        name and the value is the value to bind. @{'@param1' = 'myValue'}.
        This prevents sql injection.

    .Example
        Start-ExecuteReader -Connection $connection -Query "SELECT * FROM table"

        Executes a query without any bound parameters and returns rows found. 

    .Example
        Start-ExecuteReader -Connection $connection -Query "SELECT * FROM table WHERE id > @id" -Parameters @{ "@id"=1; }

        Executes a query with bound parameters.
#>
function Invoke-SQLiteExecuteReader {
    param (
        [Parameter(Mandatory=$True)]
        [System.Data.SQLite.SQLiteConnection]
        $Connection,

        [Parameter(Mandatory=$True)]
        [String]
        $Query,

        [Parameter()]
        [Hashtable]
        $Parameters = @{}
    )
   
    if ( $Connection.State -eq "Closed" ) {
        $Connection.Open()
    }

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Query

    foreach ( $key in $Parameters.Keys ) {
        $param = $cmd.CreateParameter()
        $param.ParameterName = $key
        $param.Value = $Parameters[$key]

        $Null = $cmd.Parameters.Add($param)
    }

    $reader = $cmd.ExecuteReader()
    $cols = @($reader.GetSchemaTable() | Select -ExpandProperty ColumnName)
    $results = @()

    while ( $reader.Read() ) {
        $row = @{}
        
        foreach ( $col in $cols ) {
            $row.Add($col, $reader[$col])
            if ( [System.DBNull]::Value.Equals($row[$col]) ) { $row[$col] = $null }
        }

        $results += New-Object PSObject -Property ($row)
    }

    $reader.Close()
    $Connection.Close()

    $results
}