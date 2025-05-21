declare module 'nbformat' {
  export interface INotebookContent {
    cells: ICell[];
    metadata: {
      kernelspec: {
        display_name: string;
        language: string;
        name: string;
      };
      language_info: {
        name: string;
        version: string;
      };
    };
    nbformat: number;
    nbformat_minor: number;
  }

  export interface ICell {
    cell_type: 'code' | 'markdown' | 'raw';
    metadata: any;
    source: string[] | string;
    execution_count?: number | null;
    outputs?: any[];
  }
}