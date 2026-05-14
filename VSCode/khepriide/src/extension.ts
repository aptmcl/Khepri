// The module 'vscode' contains the VS Code extensibility API.
import * as vscode from 'vscode';

interface JuliaExecutionResult {
	all: string;
}

interface JuliaExecuteOptions {
	showCodeInREPL: boolean;
	showResultInREPL: boolean;
}

interface JuliaApi {
	executeInREPL(code: string, options: JuliaExecuteOptions): Thenable<JuliaExecutionResult>;
}

const replOptions: JuliaExecuteOptions = {
	showCodeInREPL: false,
	showResultInREPL: false,
};

const highlightDecorationTypes =
	[0.7, 0.5, 0.3, 0.2, 0.1, 0.05, 0.025].map(alpha => vscode.window.createTextEditorDecorationType({
		backgroundColor: `RGB(132, 157, 204, ${alpha})`,
		// backgroundColor: new vscode.ThemeColor('editor.hoverHighlightBackground')
	}));

function clearHighlightDecorationTypes(editor: vscode.TextEditor) {
	highlightDecorationTypes.forEach(decoration => editor.setDecorations(decoration, []));
}

function isJuliaApi(value: unknown): value is JuliaApi {
	const candidate = value as { executeInREPL?: unknown };
	return typeof candidate === 'object'
		&& candidate !== null
		&& typeof candidate.executeInREPL === 'function';
}

async function activateJuliaApi(): Promise<JuliaApi | undefined> {
	const juliaExtension = vscode.extensions.getExtension('julialang.language-julia');
	if (juliaExtension === undefined) {
		vscode.window.showInformationMessage('Could not find the Julia extension!');
		return undefined;
	}

	try {
		const juliaExports = juliaExtension.isActive ? juliaExtension.exports : await juliaExtension.activate();
		if (isJuliaApi(juliaExports)) {
			return juliaExports;
		}
		vscode.window.showWarningMessage('The Julia extension does not expose executeInREPL.');
	} catch (error) {
		console.error('Julia extension activation failed!', error);
		vscode.window.showWarningMessage('Julia extension activation failed.');
	}

	return undefined;
}

async function executeInJulia(juliaApi: JuliaApi, code: string): Promise<JuliaExecutionResult | undefined> {
	try {
		return await juliaApi.executeInREPL(code, replOptions);
	} catch (error) {
		console.error('Julia REPL execution failed.', error);
		vscode.window.showWarningMessage('Could not execute the Khepri command in the Julia REPL.');
		return undefined;
	}
}

function juliaStringLiteral(value: string): string {
	return JSON.stringify(value);
}

function parseTraceResult(output: string): any[] {
	const ans = output.substring(4, output.length - 4);
	return JSON.parse(ans);
}

async function highlightSourceShapes(juliaApi: JuliaApi, editor: vscode.TextEditor) {
	const position = editor.selection.active;
	const filePath = editor.document.uri.fsPath;
	clearHighlightDecorationTypes(editor);
	await executeInJulia(
		juliaApi,
		`KhepriBase.highlight_source_shapes(${juliaStringLiteral(filePath)}, ${position.line + 1})`,
	);
}

export async function activate(context: vscode.ExtensionContext) {
	const juliaApi = await activateJuliaApi();
	if (juliaApi === undefined) {
		return;
	}

	void vscode.commands.executeCommand('language-julia.startREPL');

	const disposable1 = vscode.commands.registerCommand('khepriide.generatingCode', async () => {
		const res = await executeInJulia(juliaApi, 'KhepriBase.select_shape_sources_string()');
		if (res === undefined) {
			return;
		}

		const editor = vscode.window.activeTextEditor;
		if (editor) {
			clearHighlightDecorationTypes(editor);

			let results: any[];
			try {
				results = parseTraceResult(res.all);
			} catch (error) {
				console.error('Could not parse Khepri trace result.', error);
				return;
			}

			const fsPath = editor.document.uri.fsPath;
			results
				.filter((fl: any[]) => fl[0] === fsPath)
				.forEach((result: any[], i: number) => {
					if (i < highlightDecorationTypes.length) {
						const lineNumber = result[1] - 1; // Julia is one-based.
						if (lineNumber >= 0 && lineNumber < editor.document.lineCount) {
							const line = editor.document.lineAt(lineNumber);
							const range = new vscode.Range(line.range.start, line.range.end);
							editor.setDecorations(highlightDecorationTypes[i], [range]);
						}
					}
				});
		}
	});
	context.subscriptions.push(disposable1);

	const disposable2 = vscode.commands.registerCommand('khepriide.generatedShapes', () => {
		const editor = vscode.window.activeTextEditor;
		if (editor) {
			void highlightSourceShapes(juliaApi, editor);
		}
	});
	context.subscriptions.push(disposable2);

	context.subscriptions.push(vscode.window.onDidChangeTextEditorSelection(event => {
		void highlightSourceShapes(juliaApi, event.textEditor);
	}));
}

export function deactivate() {}
