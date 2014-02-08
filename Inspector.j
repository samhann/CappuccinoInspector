@import <Foundation/CPObject.j>
@import <AppKit/CALayer.j>
@import "LPMultiLineTextField.j"

var lexer = new ObjectiveJ.Lexer('objj_msgSend(objj_msgSend(self, "placing"), "isRotatable");');


var unpreprocessText = function(aString) {

    var lexer = new ObjectiveJ.Lexer(aString);

    return processText(lexer);
}

var processText = function(tokens) {

    var output = "";

    while((token = tokens.next()) != undefined) {

        if (token === 'objj_msgSend') {

            tokens.previous();
            output += processMsgSend(tokens);

        }
        else {
            output += token;
        }
    }

    return output;
}


var processMsgSend = function (tokens) {

   var token = tokens.next();
   var output = "";

   output += "[";
       // get rid of opening (
   tokens.skip_whitespace();

   output += processElementUptoComma(tokens);

   // consume space ..
   output += " ";

   token = tokens.skip_whitespace();

   var selectorString = token.slice(1,token.length - 1);
   var selectorParts = selectorString.split(":");
   var partCtr = 0;

   tokens.skip_whitespace();
   tokens.previous();

   var lookAhead = tokens.peek();

   if(lookAhead === ')') {
        output += selectorParts[partCtr]+ "]";
        tokens.next();
        return output;
    }

    while(1) {
    token = tokens.skip_whitespace();

    output = output + selectorParts[partCtr] + ":" + processElementUptoComma(tokens)+" ";
    partCtr = partCtr + 1;
    var lookAhead2 = tokens.peek();
    if(lookAhead2 === ')' ) {
        tokens.next();
        break;
    }
  }

  output += "]";

  return output;
}


var processBalancedParensExp = function(tokens) {

   var output = "";

   var token = undefined;
   tokens.next();
   output += "("

   while((token = tokens.peek(YES)) != ')' && token != undefined) {

        if (token === "(") {

            output+= processBalancedParensExp(tokens);
        }
        else if(token === "objj_msgSend"){
            output+= processMsgSend(tokens);
        }
        else {

            output += tokens.skip_whitespace();
        }

   }
     tokens.next();
     output+=")";
     return output;
}

var processElementUptoComma = function(tokens) {

    var output = "";

    var token = undefined;

    while((token = tokens.peek(YES)) != ',' && token != undefined) {

       // debugger;

        if(token === "objj_msgSend") {
            output += processMsgSend(tokens);
        }

        else if(token === "(") {
            output += processBalancedParensExp(tokens);
        }
        else {

            output += tokens.skip_whitespace();
        }
        if(tokens.peek(YES) === ')') {

             return output;
            }
    }
     tokens.skip_whitespace();
    return output;
}

@implementation InspectorController : CPObject

{
    CPArray classList @accessors;
    CPObject delegate @accessors;
    CPTextField classTextField @accessors;
    CPTextField methodBodyTextField @accessors;
    var         currentClass @accessors;
}

- (var)init
{
    self = [super init];

    if (self) {

        classList = objj_getAllClasses();
    }

    return self;
}

- (void)searchClass:(id)sender
{

   var className = [classTextField stringValue];

   CPLog.trace("Searching for class .."+className);


   if(classList[className]) {

       self.currentClass = objj_getClass(className);
      [delegate reloadTableViewWithClass:[CPString stringWithString:className]];

   }
}

- (void)addMethod:(var)sender
{
    var methodBody = self.methodBodyTextField._stringValue;
    var lexer = new ObjectiveJ.Lexer(methodBody);
    var stringBuffer = ObjectiveJ.preprocessMethod(lexer);

    var functionBody = stringBuffer.atoms.join('');

    var functionObject = objj_eval(functionBody);

    class_addMethod(self.currentClass,functionObject.name,functionObject.method_imp,functionObject.types);

}

- (var)numberOfRowsInTableView:(CPTableView)aTableView{

    var length = Object.keys(classList).length;
    CPLog.trace("returning length as .."+length);

    return length;
}

- (id)tableView:(CPTableView)aTableView objectValueForTableColumn:(CPTableColumn)aTableColumn row:(int)aRow
{

    var returnValue = [CPString stringWithString:Object.keys(classList)[aRow]];
   return returnValue;
}

- (void)tableViewSelectionDidChange:(CPNotification)aNotification
{

    var tableView = [aNotification object];
    var selectedRow = [tableView selectedRow];
    [delegate reloadTableViewWithClass:[CPString stringWithString:Object.keys(classList)[selectedRow]]];
}


@end

@implementation MethodListController : CPObject


{
    CPArray methodList @accessors;
    CPObject delegate @accessors;
    CPTableView methodListView @accessors;
    var         currentClass @accessors;
    var         methodTextField @accessors;
    var         currentMethod @accessors;

}

- (var)init
{
    self = [super init];

    if (self) {

        methodList = [];
    }

    return self;
}

- (void)inject
{
    var functionToInject = objj_eval("("+self.methodTextField._stringValue+")");

    if(typeof functionToInject === "function" && self.currentMethod) {
         currentMethod.method_imp = functionToInject;
    }
}

- (var)numberOfRowsInTableView:(CPTableView)aTableView{


    return methodList.length;
}


- (id)tableView:(CPTableView)aTableView objectValueForTableColumn:(CPTableColumn)aTableColumn row:(int)aRow
{

    var returnValue = [CPString stringWithString:methodList[aRow].name];
    return returnValue;
}

- (void)reloadTableViewWithClass:(var)theIncomingClass
{
    currentClass = theIncomingClass;

    self.methodList = class_copyMethodList(objj_getClass(theIncomingClass))
    [self.methodListView reloadData];
    [self.methodListView deselectAll:nil];
}

- (void)preview
{
    [self.methodTextField setStringValue:[CPString stringWithString:unpreprocessText(methodTextField._stringValue)]];
}

- (void)tableViewSelectionDidChange:(CPNotification)aNotification
{

    var tableView = [aNotification object];
    var selectedRow = [tableView selectedRow];

    if(selectedRow != -1) {
        var method = self.methodList[selectedRow];

        self.currentMethod = self.methodList[selectedRow];

        [self.methodTextField setStringValue:[CPString stringWithString:method.method_imp.toString()]];
  }
  else {
    self.currentMethod = nil;
    [self.methodTextField setStringValue:@""];
  }
}

@end


@implementation Inspector : CPObject
{


  var   searchTextField;

}





+ (void)createInspectorWindowForAppController:(var)anAppController
{
    var inspectorWindow = [[CPWindow alloc] initWithContentRect:CGRectMake(100,100,950,300)
                                                       styleMask:CPClosableWindowMask | CPTitledWindowMask];

    [inspectorWindow setTitle:@"Class inspector"];


    var contentView = [inspectorWindow contentView];

    var methodListView = [[CPTableView alloc] initWithFrame:CGRectMake(0,0,0, 0)];

    var methodController = [[MethodListController alloc] init];
    [methodController setMethodListView:methodListView];
    var methodScrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(227,25,200,200)];

    [methodListView setTheme:[CPTheme defaultTheme]];
    var methodNameColumn = [[CPTableColumn alloc] initWithIdentifier:@"methodName"];
    [methodNameColumn setWidth:200];
    [[methodNameColumn headerView] setStringValue:@"Method name"];
    [methodListView addTableColumn:methodNameColumn];

    CPLog.trace("Number of columns ... "+[methodListView numberOfColumns]);
    [methodListView setDataSource:methodController];
    [methodListView setDelegate:methodController];

    [methodScrollView setHasVerticalScroller:YES];
    [methodScrollView setHasHorizontalScroller:YES];

    [methodScrollView setDocumentView:methodListView];
    [contentView addSubview:methodScrollView];


    var controller = [[InspectorController alloc] init];
    controller.delegate = methodController;
    var scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(25,25,200,200)];

    var classListView = [[CPTableView alloc] initWithFrame:CGRectMake(0,0,0, 0)];
    [classListView setTheme:[CPTheme defaultTheme]];
    var classNameColumn = [[CPTableColumn alloc] initWithIdentifier:@"className"];
    [classNameColumn setWidth:200];
    [[classNameColumn headerView] setStringValue:@"Class"];
    [classListView addTableColumn:classNameColumn];

    [classListView setDataSource:controller];
    [classListView setDelegate:controller];

    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setTheme:[CPTheme defaultTheme]];

    [scrollView setDocumentView:classListView];

    var textStringField = [LPMultiLineTextField textFieldWithStringValue:""
                                                         placeholder:""
                                                               width:330];

    [textStringField setFrame:CGRectMake(430,55,500,120)];
    [textStringField setLineBreakMode:CPLineBreakByWordWrapping];
    [textStringField setSelectable:YES];
    [textStringField setFont:[CPFont systemFontOfSize:12.0]];
    [methodController setMethodTextField:textStringField];

    [contentView addSubview:textStringField];

    [contentView addSubview:scrollView];

    var injectButton = [CPButton buttonWithTitle:@"Inject"];
    [injectButton setFrameOrigin:CGPointMake(500,225)];
    [injectButton setTarget:methodController];
    [injectButton setAction:@selector(inject)];

    var previewButton = [CPButton buttonWithTitle:@"previewButton"];
    [previewButton setFrameOrigin:CGPointMake(CGRectGetMaxX([injectButton frame]),225)];
    [previewButton setTarget:methodController];
    [previewButton setAction:@selector(preview)];


    var searchField =  [CPTextField textFieldWithStringValue:@"" placeholder:"Class name" width:100]
    [searchField setFrameOrigin:CGPointMake(25,225)];
    [searchField sizeToFit];

    [contentView addSubview:searchField];

    var searchButton = [CPButton buttonWithTitle:@"Search"];
    [searchButton setFrameOrigin:CGPointMake(CGRectGetMaxX([searchField frame]),225)];
    [searchButton setTarget:controller];
    [searchButton setAction:@selector(searchClass:)];
    [controller setClassTextField:searchField];


    var addMethodButton = [CPButton buttonWithTitle:@"Add Method"];
    [addMethodButton setFrameOrigin:CGPointMake(CGRectGetMaxX([searchButton frame]),225)];
    [addMethodButton setTarget:controller];
    [addMethodButton setAction:@selector(addMethod:)];
    [controller setClassTextField:searchField];


    [controller setMethodBodyTextField:textStringField];
    [contentView addSubview:injectButton];
    [contentView addSubview:searchButton];
    [contentView addSubview:previewButton];
    [contentView addSubview:addMethodButton];


    [inspectorWindow orderFront:anAppController];
}

@end

