import 'package:pdf_engine_api/pdf_engine_api.dart';
import 'package:test/test.dart';

void main() {
  test('engine descriptors expose a capability contract', () {
    const descriptor = PdfEngineDescriptor(
      id: 'test',
      label: 'Test engine',
      capabilities: {PdfEngineCapability.render},
      experimental: true,
    );

    expect(descriptor.capabilities, {PdfEngineCapability.render});
    expect(descriptor.experimental, isTrue);
  });
}
