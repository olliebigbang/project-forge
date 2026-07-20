export class InterpreterError extends Error {
  constructor(code, message, status = 502, retrySafe = false) {
    super(message);
    this.name = "InterpreterError";
    this.code = code;
    this.status = status;
    this.retrySafe = retrySafe;
  }
}
