# MCYeti style guide

## Function calls
This is how a function call must be formatted:
```
myfunc(arg1, arg2);
```
- no space between the name and the (
- space after commas

## Import structure
#### Order of imports
1. standard libraryes
2. 3rd party libraries
4. imports from this project

Imports must be ordered based on the length of the text

## Pointer definitions
```
int* b;
```
The pointer must be on the left side

## Statements
```
if (...) {
	
}
else {
	
}
```
- } must be on a line on its own
- { must be on the line with the statement

## Naming
- camelCase for variables
- PascalCase for functions
- PascalCase for classes/structs/enums/aliases etc
- camelCase for module names

## Function definitions
```
void myfunc() {
	
}
```

## Comments
- use `//` for single linecomments

## Line length
- Limited to 80 characters
- If lines are too long with paranthesis, split like this:
```
... (
	...
)
...
```
