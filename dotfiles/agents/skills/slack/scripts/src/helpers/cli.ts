// CLI arg parsing, output formatting, error handling.

export interface ParsedArgs {
  flags: Record<string, string | boolean>;
  positional: string[];
}

export function parseArgs(args: string[]): ParsedArgs {
  const flags: Record<string, string | boolean> = {};
  const positional: string[] = [];
  for (let i = 0; i < args.length; i++) {
    const arg = args[i]!;
    if (arg.startsWith("--")) {
      const key = arg.slice(2);
      const next = args[i + 1];
      if (next !== undefined && !next.startsWith("--")) {
        flags[key] = next;
        i++;
      } else {
        flags[key] = true;
      }
    } else {
      positional.push(arg);
    }
  }
  return { flags, positional };
}

export function output(data: unknown): void {
  console.log(JSON.stringify(data, null, 2));
}

export class FatalError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "FatalError";
  }
}

export class UsageError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "UsageError";
  }
}

export function fatal(msg: string): never {
  throw new FatalError(msg);
}

export function usage(text: string): never {
  throw new UsageError(text);
}
