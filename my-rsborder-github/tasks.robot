*** Settings ***
Documentation     Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.


Library    RPA.Browser.Selenium    auto_close=${TRUE}
Library    RPA.HTTP
Library    RPA.PDF
Library    RPA.Tables
Library    RPA.Archive
Library    RPA.Dialogs
Library    RPA.Robocorp.Vault
Library    RPA.FileSystem


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website
    ${orders} =    Get orders
    FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        Submit the order
        ${pdf} =    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot} =    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
    END
    Create a ZIP file of the receipts
    ${userName} =    Collect Information From User
    Show Completion Message    ${userName}


*** Keywords ***
Open the robot order website
    ${secret} =    Get Secret    vault
    Open Available Browser    ${secret}[appUrl]
    Empty Directory    ${OUTPUT_DIR}${/}Receipts
    Empty Directory    ${OUTPUT_DIR}${/}Images
    Remove File    ${OUTPUT_DIR}${/}Receipts.zip

Get orders
    ${secret} =    Get Secret    vault
    Download    ${secret}[inputFileUrl]    overwrite=True
    ${robot_orders} =    Read table from CSV    orders.csv    true
    Return From Keyword    ${robot_orders} 
    [Teardown]        Remove File    orders.csv    

Close the annoying modal
    Click Button    //button[text()='OK']

Fill the form
    [Arguments]    ${row}
    Select From List By Index    head    ${row}[Head]
    Set Local Variable    ${bodyId}    id:id-body-
    ${bodyId} =    Catenate    SEPARATOR=    ${bodyId}    ${row}[Body]    
    Click Element    ${bodyId}
    Input Text    xpath://input[contains(@placeholder,'Enter the part number for the legs')]    ${row}[Legs]
    Input Text    address    ${row}[Address]

Preview the robot
    Click Button    id:preview

Submit the order
    Wait Until Keyword Succeeds    10x    100ms    Submit the order Without retry
        
Submit the order Without retry
    Click Button    id:order
    Wait Until Element Is Visible    id:receipt    100ms

Store the receipt as a PDF file
    [Arguments]    ${order_number}
    ${DirNotExists}=    Does Directory Not Exist    ${OUTPUT_DIR}${/}Receipts
    IF    ${DirNotExists}
        Create Directory    ${OUTPUT_DIR}${/}Receipts
    END   
    Wait Until Element Is Visible    id:receipt
    ${file_name} =    Catenate    SEPARATOR=    ${OUTPUT_DIR}${/}Receipts${/}receipt_    ${order_number}    .pdf
    Remove File    ${file_name}
    ${receipt_html} =    Get Element Attribute    id:receipt    outerHTML
    Html To Pdf    ${receipt_html}    ${file_name}
    Return From Keyword    ${file_name}

Take a screenshot of the robot
    [Arguments]    ${order_number}
    ${DirNotExists}=    Does Directory Not Exist    ${OUTPUT_DIR}${/}Images
    IF    ${DirNotExists}
        Create Directory    ${OUTPUT_DIR}${/}Images
    END   
    Wait Until Element Is Visible    id:robot-preview-image
    # ${file_name} =    Catenate    SEPARATOR=    ${OUTPUT_DIR}${/}robot_preview_    ${order_number}    .pdf
    # ${html} =    Get Element Attribute    id:robot-preview-image    outerHTML
    # Html To Pdf    ${html}    ${file_name}
    ${file_name} =    Catenate    SEPARATOR=    ${OUTPUT_DIR}${/}Images${/}robot_preview_    ${order_number}    .png
    Remove File    ${file_name}
    Capture Element Screenshot    id:robot-preview-image    ${file_name}
    Return From Keyword    ${file_name}  

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshot}    ${pdf}
    Add Watermark Image To Pdf  ${screenshot}    ${pdf}    ${pdf}
    [Teardown]    Remove Files    ${screenshot}

Go to order another robot
    Click Element    id:order-another

Create a ZIP file of the receipts
    Remove File    ${OUTPUT_DIR}${/}Receipts.zip
    Archive Folder With Zip    ${OUTPUT_DIR}${/}Receipts    ${OUTPUT_DIR}${/}Receipts.zip   include=*receipt*.pdf    recursive=False
    [Teardown]    Remove Directories

Remove Directories
    Remove Directory     ${OUTPUT_DIR}${/}Receipts    True
    Remove Directory     ${OUTPUT_DIR}${/}Images    True

Collect Information From User
    Add text input    search    label=Search What is your name?
    ${response} =    Run dialog
    [Return]    ${response.search}

Show Completion Message
    [Arguments]    ${userName}
    Add icon    Success    
    Add heading    Your BOTs are ordered ${userName}!
    Add text    ${\n}See Receipts.zip
    Add submit buttons    buttons=OK    default=OK
    ${result}=    Run dialog