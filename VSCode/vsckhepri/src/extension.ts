import * as vscode from 'vscode';

const highlightDecorationTypes = 
    [0.7, 0.5, 0.3, 0.2, 0.1, 0.05, 0.025].map(alpha => vscode.window.createTextEditorDecorationType({
        backgroundColor: `RGB(132, 157, 204, ${alpha})`,
    }));

function clearHighlightDecorationTypes(editor: vscode.TextEditor) {
	highlightDecorationTypes.map(decoration=>editor.setDecorations(decoration, []));
}

export function activate(context: vscode.ExtensionContext) {

	let juliaExtension =  vscode.extensions.getExtension('julialang.language-julia');
	if (juliaExtension === undefined) {
		vscode.window.showInformationMessage("Could not find the Julia extension!");
	} else if (juliaExtension.isActive === false) {
			juliaExtension.activate().then( 
						function(){ console.log("Julia extension activated"); },
						function(){ console.log("Julia extension activation failed!"); });
	}
	vscode.commands.executeCommand("language-julia.startREPL");
	let juliaAPI = juliaExtension?.exports;
	let disposable1 = vscode.commands.registerCommand('vsckhepri.generatingCode', () => {
		juliaAPI.executeInREPL('KhepriBase.select_shape_sources_string()', 
		                       { showCodeInREPL:false, showResultInREPL:false }).then((res: { all: string; }) => {
			const editor = vscode.window.activeTextEditor;
			if (editor) {
				clearHighlightDecorationTypes(editor);
				const ans = res.all.substring(4, res.all.length-4);
				const results = JSON.parse(ans);
				const fsPath = editor.document.uri.fsPath;
				const ranges = results.filter((fl: any[]) => fl[0] === fsPath).map((result: any[], i: number) => {
						if (i < highlightDecorationTypes.length) {
								const path = result[0];
								const lineNumber = result[1] - 1; //Julia is one-based
								const line = editor.document.lineAt(lineNumber);
								const range = new vscode.Range(line.range.start, line.range.end);
								editor.setDecorations(highlightDecorationTypes[i], [range]);
						}
				});
			}
		});
	});
	context.subscriptions.push(disposable1);
	let disposable2 = vscode.commands.registerCommand('vsckhepri.generatedShapes', () => {
		const editor = vscode.window.activeTextEditor;
		if (editor) {
			clearHighlightDecorationTypes(editor);
    	const document = editor.document;
    	const position = editor.selection.active;
    	const filePath = document.uri.fsPath;
    	const lineNumber = position.line + 1;
    	juliaAPI.executeInREPL(`KhepriBase.highlight_source_shapes(raw"${filePath}", ${lineNumber})`, 
														 { showCodeInREPL:false, showResultInREPL:false }).then((res: { all: string; }) => {
				vscode.window.activeTextEditor = editor;
			});
		}
	});
	context.subscriptions.push(disposable2);
	const disposable = vscode.window.onDidChangeTextEditorSelection((event) => {
    const editor = event.textEditor;
    const position = editor.selection.active;
		const filePath = editor.document.uri.fsPath;
		clearHighlightDecorationTypes(editor);
		juliaAPI.executeInREPL(`KhepriBase.highlight_source_shapes(raw"${filePath}", ${position.line+1})`, 
														 { showCodeInREPL:false, showResultInREPL:false}).then((res: { all: string; }) => {})});
	}

export function deactivate() {}
